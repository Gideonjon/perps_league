import '../core/format.dart';
import 'dreamdex_models.dart';
import 'indexer_client.dart';

/// Read-only access to dreamDEX perps through the public indexer.
///
/// Query shapes mirror `@somnia-chain/markets-sdk@0.32.1`
/// (src/perp/state.ts, src/perp/history.ts, src/candles.ts), so they only
/// select columns the deployed indexer serves.
class DreamDexRepository {
  DreamDexRepository({IndexerClient? client}) : _gql = client ?? IndexerClient();

  final IndexerClient _gql;

  Map<String, PerpMarket>? _marketsByPool;
  DateTime? _marketsLoadedAt;
  Future<Map<String, PerpMarket>>? _inflight;

  static const _marketsQuery = r'''
query PerpMarkets {
  Market(where: { marketType: { _eq: "PERP" } }, limit: 200) {
    poolAddress
    baseSymbol
    quoteSymbol
    baseDecimals
    quoteDecimals
    lastPrice
    markPrice
    indexPrice
    fundingRate
    fundingWindowSec
    openInterest
    tradeCount
  }
}
''';

  static const _positionsQuery = r'''
query PerpPositions($where: PerpPosition_bool_exp!, $limit: Int) {
  PerpPosition(where: $where, order_by: { updatedAt: desc }, limit: $limit) {
    pool
    size
    isLong
    entryPriceX18
    updatedAt
  }
}
''';

  static const _changesQuery = r'''
query PerpPositionChanges($where: PerpPositionChange_bool_exp!, $orderBy: [PerpPositionChange_order_by!], $limit: Int, $offset: Int) {
  PerpPositionChange(where: $where, order_by: $orderBy, limit: $limit, offset: $offset) {
    id
    pool
    kind
    sizeBefore
    sizeAfter
    closedSize
    entryPriceBefore
    entryPriceAfter
    exitPrice
    realizedPnl
    timestamp
    txHash
  }
}
''';

  static const _candlesQuery = r'''
query Candles($where: Candle_bool_exp!, $limit: Int) {
  Candle(where: $where, order_by: [{ bucketStart: desc }], limit: $limit) {
    bucketStart
    openPrice
    high
    low
    closePrice
    baseVolume
  }
}
''';

  /// All perp markets, keyed by lowercased pool. Cached for 30 seconds so a
  /// leaderboard refresh across many members costs one markets read.
  Future<Map<String, PerpMarket>> marketsByPool({bool refresh = false}) {
    final fresh = _marketsLoadedAt != null &&
        DateTime.now().difference(_marketsLoadedAt!) < const Duration(seconds: 30);
    if (!refresh && fresh && _marketsByPool != null) return Future.value(_marketsByPool!);
    return _inflight ??= _loadMarkets().whenComplete(() => _inflight = null);
  }

  Future<Map<String, PerpMarket>> _loadMarkets() async {
    final data = await _gql.query(_marketsQuery);
    final rows = (data['Market'] as List? ?? const []).cast<Map<String, dynamic>>();
    final map = <String, PerpMarket>{};
    for (final r in rows) {
      final m = PerpMarket.fromJson(r);
      if (m.pool.isNotEmpty) map[m.pool] = m;
    }
    _marketsByPool = map;
    _marketsLoadedAt = DateTime.now();
    return map;
  }

  Future<List<PerpMarket>> markets({bool refresh = false}) async {
    final map = await marketsByPool(refresh: refresh);
    final list = map.values.toList()..sort((a, b) => b.tradeCount.compareTo(a.tradeCount));
    return list;
  }

  /// Open positions for a wallet. Closed positions linger in the indexer as
  /// size-0 rows, so they are filtered out here.
  Future<List<OpenPosition>> openPositions(String wallet) async {
    final markets = await marketsByPool();
    final data = await _gql.query(_positionsQuery, {
      'where': {
        'account': {'_eq': wallet.toLowerCase()},
      },
      'limit': 100,
    });
    final rows = (data['PerpPosition'] as List? ?? const []).cast<Map<String, dynamic>>();
    final out = <OpenPosition>[];
    for (final r in rows) {
      final market = markets[(r['pool'] ?? '').toString().toLowerCase()];
      if (market == null) continue;
      final abs = fromRaw(r['size'], market.baseDecimals);
      if (abs == 0) continue;
      final isLong = r['isLong'] == true;
      out.add(OpenPosition(
        market: market,
        size: isLong ? abs : -abs,
        // Column is named entryPriceX18 but is NOT 1e18-scaled: raw quote
        // units per whole base (see SDK IndexedPerpPosition.avgEntryPrice).
        entryPrice: fromRaw(r['entryPriceX18'], market.quoteDecimals),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(toInt(r['updatedAt']) * 1000),
      ));
    }
    return out;
  }

  /// Every position update for [wallet] in `[from, to)`, oldest first.
  Future<List<TradeEvent>> tradeEvents(
    String wallet, {
    required DateTime from,
    required DateTime to,
    int maxRows = 3000,
  }) async {
    final markets = await marketsByPool();
    final acct = wallet.toLowerCase();
    const page = 1000;
    final out = <TradeEvent>[];
    var offset = 0;
    while (out.length < maxRows) {
      final data = await _gql.query(_changesQuery, {
        'where': {
          'account': {'_eq': acct},
          'timestamp': {
            '_gte': (from.millisecondsSinceEpoch ~/ 1000).toString(),
            '_lt': (to.millisecondsSinceEpoch ~/ 1000).toString(),
          },
        },
        'orderBy': [
          {'blockNumber': 'asc'},
          {'logIndex': 'asc'},
        ],
        'limit': page,
        'offset': offset,
      });
      final rows = (data['PerpPositionChange'] as List? ?? const []).cast<Map<String, dynamic>>();
      for (final r in rows) {
        final market = markets[(r['pool'] ?? '').toString().toLowerCase()];
        out.add(TradeEvent.fromJson(r, acct, market));
      }
      if (rows.length < page) break;
      offset += page;
    }
    return out;
  }

  /// Most recent [limit] candles for a pool, oldest first.
  /// Valid intervals (seconds): 60, 300, 900, 3600, 14400, 86400.
  Future<List<Candle>> candles(PerpMarket market, int intervalSeconds, {int limit = 120}) async {
    final data = await _gql.query(_candlesQuery, {
      'where': {
        'pool': {'_eq': market.pool},
        'intervalSeconds': {'_eq': intervalSeconds},
      },
      'limit': limit,
    });
    final rows = (data['Candle'] as List? ?? const []).cast<Map<String, dynamic>>();
    final qd = market.quoteDecimals;
    final list = rows
        .map((r) => Candle(
              start: DateTime.fromMillisecondsSinceEpoch(toInt(r['bucketStart']) * 1000),
              open: fromRaw(r['openPrice'], qd),
              high: fromRaw(r['high'], qd),
              low: fromRaw(r['low'], qd),
              close: fromRaw(r['closePrice'], qd),
              volume: fromRaw(r['baseVolume'], market.baseDecimals),
            ))
        .toList();
    list.sort((a, b) => a.start.compareTo(b.start));
    return list;
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:perps_league/core/format.dart';
import 'package:perps_league/data/dreamdex_models.dart';
import 'package:perps_league/data/stats.dart';

PerpMarket _eth() => PerpMarket.fromJson({
      'poolAddress': '0xABCDEF0000000000000000000000000000000001',
      'baseSymbol': 'ETH',
      'quoteSymbol': 'USDso',
      'baseDecimals': 18,
      'quoteDecimals': 6,
      'lastPrice': '3000000000', // 3000.000000
      'markPrice': '3100000000', // 3100.000000
      'indexPrice': '3099000000',
      'fundingRate': '100000000000000', // 1e14 / 1e18 = 0.0001 = 0.01%
      'fundingWindowSec': 28800,
      'openInterest': '5000000000000000000',
      'tradeCount': 42,
    });

Map<String, dynamic> _change({
  required String id,
  required String kind,
  required String before,
  required String after,
  String closed = '0',
  String? entryBefore,
  String entryAfter = '0',
  String? exit,
  String pnl = '0',
  int ts = 1760000000,
}) =>
    {
      'id': id,
      'pool': '0xabcdef0000000000000000000000000000000001',
      'kind': kind,
      'sizeBefore': before,
      'sizeAfter': after,
      'closedSize': closed,
      'entryPriceBefore': entryBefore,
      'entryPriceAfter': entryAfter,
      'exitPrice': exit,
      'realizedPnl': pnl,
      'timestamp': '$ts',
      'txHash': '0xtx$id',
    };

void main() {
  test('raw indexer units convert to human values', () {
    expect(fromRaw('3000000000', 6), 3000);
    expect(fromRaw('-1500000', 6), -1.5);
    expect(fromRaw('1000000000000000000', 18), 1);
    expect(fromRaw(null, 6), 0);
  });

  test('market parses decimals, lowercases pool and reads funding', () {
    final m = _eth();
    expect(m.pool, '0xabcdef0000000000000000000000000000000001');
    expect(m.price, 3100);
    expect(m.symbol, 'ETH-PERP');
    expect(m.fundingPercentPerWindow, closeTo(0.01, 1e-12));
    expect(m.openInterest, 5);
  });

  test('stats sum realized PnL on closes only and count wins', () {
    final m = _eth();
    const w = '0xuser';
    final events = [
      // Open 1 ETH long at 3000.
      _change(id: '1_0', kind: 'OPEN', before: '0', after: '1000000000000000000', entryAfter: '3000000000'),
      // Close it at 3200: +200.
      _change(
        id: '2_0',
        kind: 'CLOSE',
        before: '1000000000000000000',
        after: '0',
        closed: '1000000000000000000',
        entryBefore: '3000000000',
        exit: '3200000000',
        pnl: '200000000',
      ),
      // Open 0.5 short at 3200, then close at 3300: -50.
      _change(id: '3_0', kind: 'OPEN', before: '0', after: '-500000000000000000', entryAfter: '3200000000'),
      _change(
        id: '4_0',
        kind: 'CLOSE',
        before: '-500000000000000000',
        after: '0',
        closed: '500000000000000000',
        entryBefore: '3200000000',
        exit: '3300000000',
        pnl: '-50000000',
      ),
    ].map((j) => TradeEvent.fromJson(j, w, m)).toList();

    final pos = OpenPosition(market: m, size: 2, entryPrice: 3000, updatedAt: DateTime(2026));

    final stats = TraderStats(
      wallet: w,
      events: events,
      openPositions: [pos],
      includeUnrealized: true,
      computedAt: DateTime(2026),
    );

    expect(stats.realizedPnl, closeTo(150, 1e-9));
    expect(stats.unrealizedPnl, closeTo(200, 1e-9)); // 2 * (3100 - 3000)
    expect(stats.totalPnl, closeTo(350, 1e-9));
    expect(stats.closedTrades, 2);
    expect(stats.wins, 1);
    expect(stats.winRate, 50);
    expect(stats.tradesTaken, 2);
    expect(stats.bestTrade!.realizedPnl, closeTo(200, 1e-9));
    expect(stats.worstTrade!.realizedPnl, closeTo(-50, 1e-9));
    expect(stats.equityCurve, [0, 200, 150]);

    expect(events[1].isLong, isTrue); // closed a long
    expect(events[3].isLong, isFalse); // closed a short
    expect(events[1].returnPercent, closeTo(200 / 3000 * 100, 1e-9));
  });

  test('unrealized is ignored once the window has ended', () {
    final m = _eth();
    final stats = TraderStats(
      wallet: '0x',
      events: const [],
      openPositions: [OpenPosition(market: m, size: -1, entryPrice: 3000, updatedAt: DateTime(2026))],
      includeUnrealized: false,
      computedAt: DateTime(2026),
    );
    expect(stats.unrealizedPnl, 0);
    expect(stats.totalPnl, 0);
  });

  test('wallet validation and formatting', () {
    expect(isValidWallet('0x478769E1177C0773c43A593DCCc4Ad15F15F1394'), isTrue);
    expect(isValidWallet('0x1234'), isFalse);
    expect(formatUsd(1204.5, signed: true), '+1,204.50');
    expect(formatUsd(-37.1), '-37.10');
    expect(shortAddress('0x478769E1177C0773c43A593DCCc4Ad15F15F1394'), '0x4787…1394');
  });
}

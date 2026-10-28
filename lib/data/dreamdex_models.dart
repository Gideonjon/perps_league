import '../core/format.dart';

/// A dreamDEX perp market, from the indexer `Market` entity (marketType PERP).
class PerpMarket {
  PerpMarket({
    required this.pool,
    required this.baseSymbol,
    required this.quoteSymbol,
    required this.baseDecimals,
    required this.quoteDecimals,
    required this.lastPrice,
    required this.markPrice,
    required this.indexPrice,
    required this.fundingRateRaw,
    required this.fundingWindowSec,
    required this.openInterest,
    required this.tradeCount,
  });

  /// Pool address, lowercased. On perps the market id is the pool address.
  final String pool;
  final String baseSymbol;
  final String quoteSymbol;
  final int baseDecimals;
  final int quoteDecimals;
  final double lastPrice;
  final double markPrice;
  final double indexPrice;

  /// Signed, 1e18-scaled, per [fundingWindowSec] (see SDK funding.ts).
  final String? fundingRateRaw;
  final int fundingWindowSec;

  /// Open interest in whole base units.
  final double openInterest;
  final int tradeCount;

  String get symbol => '$baseSymbol-PERP';

  /// Best available price for display and marking positions.
  double get price => markPrice > 0 ? markPrice : lastPrice;

  /// Funding rate for one funding window, as a percentage.
  double get fundingPercentPerWindow => fromRaw(fundingRateRaw, 18) * 100;

  double get fundingWindowHours => fundingWindowSec / 3600;

  factory PerpMarket.fromJson(Map<String, dynamic> j) {
    final qd = toInt(j['quoteDecimals'], 6);
    final bd = toInt(j['baseDecimals'], 18);
    return PerpMarket(
      pool: (j['poolAddress'] ?? '').toString().toLowerCase(),
      baseSymbol: (j['baseSymbol'] ?? '?').toString(),
      quoteSymbol: (j['quoteSymbol'] ?? 'USDso').toString(),
      baseDecimals: bd,
      quoteDecimals: qd,
      lastPrice: fromRaw(j['lastPrice'], qd),
      markPrice: fromRaw(j['markPrice'], qd),
      indexPrice: fromRaw(j['indexPrice'], qd),
      fundingRateRaw: toStr(j['fundingRate']),
      fundingWindowSec: toInt(j['fundingWindowSec'], 28800),
      openInterest: fromRaw(j['openInterest'], bd),
      tradeCount: toInt(j['tradeCount']),
    );
  }
}

/// An open position, from the indexer `PerpPosition` entity.
///
/// The indexer row is a snapshot as of its last update; mark-dependent values
/// are computed here against the market's current mark price.
class OpenPosition {
  OpenPosition({
    required this.market,
    required this.size,
    required this.entryPrice,
    required this.updatedAt,
  });

  final PerpMarket market;

  /// Signed size in whole base units: positive long, negative short.
  final double size;
  final double entryPrice;
  final DateTime updatedAt;

  bool get isLong => size > 0;
  double get notional => size.abs() * market.price;
  double get unrealizedPnl => size * (market.price - entryPrice);
  double get unrealizedPercent =>
      entryPrice == 0 ? 0 : (market.price - entryPrice) / entryPrice * 100 * (isLong ? 1 : -1);
}

enum ChangeKind { open, increase, reduce, close, flip, unknown }

ChangeKind _kind(String? s) {
  switch (s) {
    case 'OPEN':
      return ChangeKind.open;
    case 'INCREASE':
      return ChangeKind.increase;
    case 'REDUCE':
      return ChangeKind.reduce;
    case 'CLOSE':
      return ChangeKind.close;
    case 'FLIP':
      return ChangeKind.flip;
    default:
      return ChangeKind.unknown;
  }
}

/// One update to a position, from the indexer `PerpPositionChange` entity.
/// Each row carries the PnL it realized, so closed-trade results need no
/// fill replay.
class TradeEvent {
  TradeEvent({
    required this.id,
    required this.wallet,
    required this.market,
    required this.kind,
    required this.sizeBefore,
    required this.sizeAfter,
    required this.closedSize,
    required this.entryPriceBefore,
    required this.entryPriceAfter,
    required this.exitPrice,
    required this.realizedPnl,
    required this.timestamp,
    required this.txHash,
  });

  /// `${blockNumber}_${logIndex}`, stable and unique.
  final String id;
  final String wallet;
  final PerpMarket? market;
  final ChangeKind kind;
  final double sizeBefore;
  final double sizeAfter;
  final double closedSize;
  final double? entryPriceBefore;
  final double entryPriceAfter;
  final double? exitPrice;

  /// Price PnL realized by this update, in USDso. Fees and funding are
  /// separate records on dreamDEX and are not included.
  final double realizedPnl;
  final DateTime timestamp;
  final String txHash;

  String get symbol => market?.symbol ?? 'PERP';

  /// Updates that close some or all of a position, and so realize PnL.
  bool get realizes =>
      kind == ChangeKind.reduce || kind == ChangeKind.close || kind == ChangeKind.flip;

  /// The side the trade acted on: the position being closed for closes,
  /// the position being built for opens.
  bool get isLong => realizes ? sizeBefore > 0 : sizeAfter > 0;

  String get sideLabel => isLong ? 'Long' : 'Short';

  double get displayPrice => exitPrice ?? entryPriceAfter;

  /// Return on the closed slice, as a percentage of its entry value.
  double? get returnPercent {
    final entry = entryPriceBefore;
    if (!realizes || entry == null || entry == 0 || closedSize == 0) return null;
    return realizedPnl / (closedSize * entry) * 100;
  }

  String get verb {
    switch (kind) {
      case ChangeKind.open:
        return 'opened';
      case ChangeKind.increase:
        return 'added to';
      case ChangeKind.reduce:
        return 'trimmed';
      case ChangeKind.close:
        return 'closed';
      case ChangeKind.flip:
        return 'flipped';
      case ChangeKind.unknown:
        return 'updated';
    }
  }

  factory TradeEvent.fromJson(
    Map<String, dynamic> j,
    String wallet,
    PerpMarket? market,
  ) {
    final bd = market?.baseDecimals ?? 18;
    final qd = market?.quoteDecimals ?? 6;
    final epb = j['entryPriceBefore'];
    final xp = j['exitPrice'];
    return TradeEvent(
      id: (j['id'] ?? '').toString(),
      wallet: wallet,
      market: market,
      kind: _kind(j['kind']?.toString()),
      sizeBefore: fromRaw(j['sizeBefore'], bd),
      sizeAfter: fromRaw(j['sizeAfter'], bd),
      closedSize: fromRaw(j['closedSize'], bd),
      entryPriceBefore: epb == null ? null : fromRaw(epb, qd),
      entryPriceAfter: fromRaw(j['entryPriceAfter'], qd),
      exitPrice: xp == null ? null : fromRaw(xp, qd),
      // PnL is in raw collateral units; collateral on perps is USDso, the
      // same token as the quote, so quote decimals apply.
      realizedPnl: fromRaw(j['realizedPnl'], qd),
      timestamp: DateTime.fromMillisecondsSinceEpoch(toInt(j['timestamp']) * 1000),
      txHash: (j['txHash'] ?? '').toString(),
    );
  }
}

class Candle {
  Candle({
    required this.start,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  final DateTime start;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  bool get isUp => close >= open;
}

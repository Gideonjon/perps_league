import 'dreamdex_models.dart';
import 'dreamdex_repository.dart';

/// A trader's performance over a window, computed entirely from public
/// dreamDEX indexer data. Nothing here is self-reported, so any member can
/// recompute anyone's numbers.
class TraderStats {
  TraderStats({
    required this.wallet,
    required this.events,
    required this.openPositions,
    required this.includeUnrealized,
    required this.computedAt,
  });

  final String wallet;

  /// Position updates in the window, oldest first.
  final List<TradeEvent> events;
  final List<OpenPosition> openPositions;

  /// Unrealized PnL counts only while the window is still open.
  final bool includeUnrealized;
  final DateTime computedAt;

  List<TradeEvent> get closes => events.where((e) => e.realizes).toList();

  double get realizedPnl => closes.fold(0, (s, e) => s + e.realizedPnl);

  double get unrealizedPnl =>
      includeUnrealized ? openPositions.fold(0, (s, p) => s + p.unrealizedPnl) : 0;

  double get totalPnl => realizedPnl + unrealizedPnl;

  int get closedTrades => closes.length;

  int get wins => closes.where((e) => e.realizedPnl > 0).length;

  double get winRate => closedTrades == 0 ? 0 : wins / closedTrades * 100;

  /// New positions opened (from flat, or by flipping side).
  int get tradesTaken =>
      events.where((e) => e.kind == ChangeKind.open || e.kind == ChangeKind.flip).length;

  TradeEvent? get bestTrade {
    final c = closes;
    if (c.isEmpty) return null;
    return c.reduce((a, b) => a.realizedPnl >= b.realizedPnl ? a : b);
  }

  TradeEvent? get worstTrade {
    final c = closes;
    if (c.isEmpty) return null;
    return c.reduce((a, b) => a.realizedPnl <= b.realizedPnl ? a : b);
  }

  /// Most traded market by number of updates.
  String? get favouriteMarket {
    if (events.isEmpty) return null;
    final counts = <String, int>{};
    for (final e in events) {
      counts[e.symbol] = (counts[e.symbol] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// Running realized PnL after each close, for the equity sparkline.
  List<double> get equityCurve {
    var running = 0.0;
    final out = <double>[0];
    for (final e in closes) {
      running += e.realizedPnl;
      out.add(running);
    }
    return out;
  }
}

class StatsService {
  StatsService(this._repo);

  final DreamDexRepository _repo;

  Future<TraderStats> compute(
    String wallet, {
    required DateTime from,
    required DateTime to,
  }) async {
    final now = DateTime.now();
    final end = to.isAfter(now) ? now.add(const Duration(minutes: 1)) : to;
    final live = to.isAfter(now);
    final results = await Future.wait([
      _repo.tradeEvents(wallet, from: from, to: end),
      live ? _repo.openPositions(wallet) : Future.value(<OpenPosition>[]),
    ]);
    return TraderStats(
      wallet: wallet.toLowerCase(),
      events: results[0] as List<TradeEvent>,
      openPositions: results[1] as List<OpenPosition>,
      includeUnrealized: live,
      computedAt: now,
    );
  }
}

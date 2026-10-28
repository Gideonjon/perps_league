import 'package:flutter/material.dart';

import '../core/format.dart';
import '../data/dreamdex_models.dart';
import '../data/stats.dart';
import '../theme.dart';
import 'charts.dart';
import 'common.dart';
import 'trade_tile.dart';

/// Score, stat grid, equity curve, open positions and trade history for one
/// trader. Shared by the member profile and the Me tab.
class TraderSummary extends StatelessWidget {
  const TraderSummary({super.key, required this.stats, this.maxTrades = 50});

  final TraderStats stats;
  final int maxTrades;

  @override
  Widget build(BuildContext context) {
    final best = stats.bestTrade;
    final worst = stats.worstTrade;
    final history = stats.events.reversed.take(maxTrades).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total P&L', style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 6),
                PnlText(stats.totalPnl, size: 28, weight: FontWeight.w800),
                const SizedBox(height: 14),
                SizedBox(
                  height: 56,
                  child: LayoutBuilder(
                    builder: (context, c) => Sparkline(values: stats.equityCurve, width: c.maxWidth, height: 56),
                  ),
                ),
                const SizedBox(height: 6),
                const Text('Realized P&L after each closed trade',
                    style: TextStyle(color: AppColors.muted, fontSize: 11)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        StatGrid(tiles: [
          StatTile(label: 'Realized', value: formatUsd(stats.realizedPnl, signed: true), valueColor: AppColors.pnl(stats.realizedPnl)),
          StatTile(
            label: stats.includeUnrealized ? 'Unrealized' : 'Unrealized (n/a)',
            value: formatUsd(stats.unrealizedPnl, signed: true),
            valueColor: AppColors.pnl(stats.unrealizedPnl),
          ),
          StatTile(label: 'Win rate', value: stats.closedTrades == 0 ? '—' : formatPercent(stats.winRate, places: 0, signed: false)),
          StatTile(label: 'Closed trades', value: '${stats.closedTrades}'),
          StatTile(
            label: 'Best trade',
            value: best == null ? '—' : formatUsd(best.realizedPnl, signed: true),
            valueColor: best == null ? null : AppColors.pnl(best.realizedPnl),
          ),
          StatTile(
            label: 'Worst trade',
            value: worst == null ? '—' : formatUsd(worst.realizedPnl, signed: true),
            valueColor: worst == null ? null : AppColors.pnl(worst.realizedPnl),
          ),
          StatTile(label: 'Favourite market', value: stats.favouriteMarket ?? '—'),
          StatTile(label: 'Trades opened', value: '${stats.tradesTaken}'),
        ]),
        if (stats.openPositions.isNotEmpty) ...[
          const SectionHeader('Open positions'),
          for (final p in stats.openPositions) ...[
            _PositionCard(position: p),
            const SizedBox(height: 8),
          ],
        ],
        SectionHeader('Trade history', trailing: Text('${stats.events.length}', style: const TextStyle(color: AppColors.muted))),
        if (history.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('No trades in this window.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
          ),
        for (final e in history) ...[
          TradeTile(event: e),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({required this.position});

  final OpenPosition position;

  @override
  Widget build(BuildContext context) {
    final p = position;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(p.market.symbol, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      SideBadge(isLong: p.isLong),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${formatSize(p.size.abs())} ${p.market.baseSymbol} · entry ${formatPrice(p.entryPrice)} · mark ${formatPrice(p.market.price)}',
                    style: numStyle.copyWith(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PnlText(p.unrealizedPnl, suffix: '', size: 15),
                Text(formatPercent(p.unrealizedPercent),
                    style: numStyle.copyWith(fontSize: 11, color: AppColors.pnl(p.unrealizedPnl))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

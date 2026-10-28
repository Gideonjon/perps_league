import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../data/dreamdex_models.dart';
import '../data/league_models.dart';
import '../theme.dart';
import 'common.dart';

/// One position update in a feed or trade history.
class TradeTile extends StatelessWidget {
  const TradeTile({
    super.key,
    required this.event,
    this.member,
    this.note,
    this.canNote = false,
    this.onEditNote,
  });

  final TradeEvent event;
  final LeagueMember? member;
  final TradeNote? note;
  final bool canNote;
  final VoidCallback? onEditNote;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final size = e.realizes ? e.closedSize : (e.sizeAfter.abs() - e.sizeBefore.abs()).abs();
    final pct = e.returnPercent;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (member != null) ...[
                  TraderAvatar(name: member!.displayName, wallet: member!.wallet, radius: 15),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      if (member != null)
                        TextSpan(text: '${member!.displayName} ', style: const TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: '${e.verb} ', style: const TextStyle(color: AppColors.muted)),
                      TextSpan(text: e.symbol, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                SideBadge(isLong: e.isLong),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    '${formatSize(size)} ${e.market?.baseSymbol ?? ''} @ ${formatPrice(e.displayPrice)} · ${timeAgo(e.timestamp)}',
                    style: numStyle.copyWith(color: AppColors.muted, fontSize: 12),
                  ),
                ),
                if (e.realizes)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      PnlText(e.realizedPnl, size: 15),
                      if (pct != null)
                        Text(formatPercent(pct),
                            style: numStyle.copyWith(fontSize: 11, color: AppColors.pnl(e.realizedPnl))),
                    ],
                  ),
              ],
            ),
            if (note != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(10),
                  border: const Border(left: BorderSide(color: AppColors.accent, width: 3)),
                ),
                child: Text(note!.text, style: const TextStyle(height: 1.35)),
              ),
            ],
            Row(
              children: [
                if (e.txHash.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      foregroundColor: AppColors.muted,
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: e.txHash));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Transaction hash copied')),
                      );
                    },
                    icon: const Icon(Icons.tag_rounded, size: 14),
                    label: Text(shortAddress(e.txHash), style: const TextStyle(fontSize: 12)),
                  ),
                const Spacer(),
                if (canNote && onEditNote != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(minimumSize: const Size(0, 32)),
                    onPressed: onEditNote,
                    icon: Icon(note == null ? Icons.edit_note_rounded : Icons.edit_rounded, size: 18),
                    label: Text(note == null ? 'Add note' : 'Edit note'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

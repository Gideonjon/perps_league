import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../data/league_models.dart';
import '../theme.dart';

/// A ListView that keeps its content in a readable column on wide screens
/// (web, desktop, tablets) while still scrolling from anywhere in the
/// window. On phones it is an ordinary ListView with 16 px side padding.
class ResponsiveListView extends StatelessWidget {
  const ResponsiveListView({
    super.key,
    required this.children,
    this.maxWidth = 760,
    this.top = 8,
    this.bottom = 40,
    this.physics,
  });

  final List<Widget> children;
  final double maxWidth;
  final double top;
  final double bottom;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final side = math.max(16.0, (box.maxWidth - maxWidth) / 2);
        return ListView(
          physics: physics,
          padding: EdgeInsets.fromLTRB(side, top, side, bottom),
          children: children,
        );
      },
    );
  }
}

class PnlText extends StatelessWidget {
  const PnlText(this.value, {super.key, this.size = 15, this.suffix = ' USDso', this.weight = FontWeight.w700});

  final double value;
  final double size;
  final String suffix;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${formatUsd(value, signed: true)}$suffix',
      style: numStyle.copyWith(fontSize: size, fontWeight: weight, color: AppColors.pnl(value)),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: numStyle.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.tiles});

  final List<StatTile> tiles;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      rows.add(Row(
        children: [
          Expanded(child: tiles[i]),
          const SizedBox(width: 10),
          Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox()),
        ],
      ));
      if (i + 2 < tiles.length) rows.add(const SizedBox(height: 10));
    }
    return Column(children: rows);
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final LeagueStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      LeagueStatus.live => ('LIVE', AppColors.up),
      LeagueStatus.upcoming => ('UPCOMING', AppColors.gold),
      LeagueStatus.ended => ('ENDED', AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == LeagueStatus.live) ...[
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
        ],
      ),
    );
  }
}

class SideBadge extends StatelessWidget {
  const SideBadge({super.key, required this.isLong});

  final bool isLong;

  @override
  Widget build(BuildContext context) {
    final color = isLong ? AppColors.up : AppColors.down;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(
        isLong ? 'LONG' : 'SHORT',
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.muted),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.4)),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Something went wrong',
      message: error.toString(),
      action: OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Initials avatar with a stable colour per wallet.
class TraderAvatar extends StatelessWidget {
  const TraderAvatar({super.key, required this.name, required this.wallet, this.radius = 18});

  final String name;
  final String wallet;
  final double radius;

  static const _palette = [
    Color(0xFF6C8CFF),
    Color(0xFFB8F35A),
    Color(0xFFFF9F5A),
    Color(0xFF3DDC97),
    Color(0xFFE07BFF),
    Color(0xFF4FD1E8),
    Color(0xFFFFC94D),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _palette[wallet.hashCode.abs() % _palette.length];
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.2),
      child: Text(initials, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: radius * 0.7)),
    );
  }
}

class AddressText extends StatelessWidget {
  const AddressText(this.address, {super.key});

  final String address;

  @override
  Widget build(BuildContext context) => Text(
        shortAddress(address),
        style: const TextStyle(color: AppColors.muted, fontSize: 12, fontFamily: 'monospace'),
      );
}

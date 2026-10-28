import 'package:flutter/material.dart';

import '../core/format.dart';
import '../data/league_models.dart';
import '../data/stats.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/trader_summary.dart';

class MemberProfileScreen extends StatelessWidget {
  const MemberProfileScreen({super.key, required this.member, required this.stats, required this.league});

  final LeagueMember member;
  final TraderStats stats;
  final League league;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(member.displayName)),
      body: ResponsiveListView(
        children: [
          Row(
            children: [
              TraderAvatar(name: member.displayName, wallet: member.wallet, radius: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    AddressText(member.wallet),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('In ${league.name} · computed ${timeAgo(stats.computedAt)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          TraderSummary(stats: stats),
        ],
      ),
    );
  }
}

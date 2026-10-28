import 'package:flutter/material.dart';

import '../core/format.dart';
import '../data/league_models.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'create_league_screen.dart';
import 'join_league_screen.dart';
import 'league_detail_screen.dart';

class LeaguesScreen extends StatelessWidget {
  const LeaguesScreen({super.key, required this.profile});

  final UserProfile profile;

  void _open(BuildContext context, String leagueId) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LeagueDetailScreen(leagueId: leagueId, profile: profile),
    ));
  }

  Future<void> _create(BuildContext context) async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => CreateLeagueScreen(profile: profile)),
    );
    if (id != null && context.mounted) _open(context, id);
  }

  Future<void> _join(BuildContext context) async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => JoinLeagueScreen(profile: profile)),
    );
    if (id != null && context.mounted) _open(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leagues'),
        actions: [
          IconButton(
            tooltip: 'Join with code',
            onPressed: () => _join(context),
            icon: const Icon(Icons.group_add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New league'),
      ),
      body: StreamBuilder<List<League>>(
        stream: s.store.myLeagues(profile.uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Could not load leagues: ${snap.error}'));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final leagues = snap.data!;
          if (leagues.isEmpty) {
            return EmptyState(
              icon: Icons.emoji_events_outlined,
              title: 'No leagues yet',
              message: 'Start a league and share the code with friends, or join one with a code you were sent. '
                  'Everyone trades on dreamDEX testnet; the app keeps score.',
              action: Column(
                children: [
                  FilledButton(onPressed: () => _create(context), child: const Text('Create a league')),
                  const SizedBox(height: 10),
                  OutlinedButton(onPressed: () => _join(context), child: const Text('Join with a code')),
                ],
              ),
            );
          }
          return ResponsiveListView(
            bottom: 100,
            children: [
              for (final league in leagues) ...[
                _LeagueCard(league: league, onTap: () => _open(context, league.id)),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LeagueCard extends StatelessWidget {
  const _LeagueCard({required this.league, required this.onTap});

  final League league;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final status = league.statusAt(now);
    final timing = switch (status) {
      LeagueStatus.live => 'Ends in ${formatDuration(league.endAt.difference(now))}',
      LeagueStatus.upcoming => 'Starts in ${formatDuration(league.startAt.difference(now))}',
      LeagueStatus.ended => 'Ended ${formatDate(league.endAt)}',
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.emoji_events_rounded, color: AppColors.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(league.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      '${league.memberUids.length} trader${league.memberUids.length == 1 ? '' : 's'} · $timing',
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              StatusChip(status),
            ],
          ),
        ),
      ),
    );
  }
}

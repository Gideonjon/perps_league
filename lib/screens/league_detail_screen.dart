import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../core/format.dart';
import '../data/dreamdex_models.dart';
import '../data/league_models.dart';
import '../data/stats.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/trade_tile.dart';
import 'member_profile_screen.dart';

class LeagueDetailScreen extends StatelessWidget {
  const LeagueDetailScreen({super.key, required this.leagueId, required this.profile});

  final String leagueId;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    return StreamBuilder<League?>(
      stream: s.store.league(leagueId),
      builder: (context, leagueSnap) {
        if (leagueSnap.hasError) {
          return Scaffold(appBar: AppBar(), body: Center(child: Text('${leagueSnap.error}')));
        }
        if (!leagueSnap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final league = leagueSnap.data;
        if (league == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('This league no longer exists.')));
        }
        return StreamBuilder<List<LeagueMember>>(
          stream: s.store.members(leagueId),
          builder: (context, memberSnap) {
            if (memberSnap.hasError) {
              return Scaffold(appBar: AppBar(title: Text(league.name)), body: Center(child: Text('${memberSnap.error}')));
            }
            if (!memberSnap.hasData) {
              return Scaffold(appBar: AppBar(title: Text(league.name)), body: const Center(child: CircularProgressIndicator()));
            }
            return _LeagueBody(league: league, members: memberSnap.data!, profile: profile);
          },
        );
      },
    );
  }
}

/// Result of computing one member's stats.
class MemberResult {
  MemberResult(this.member, {this.stats, this.error});

  final LeagueMember member;
  final TraderStats? stats;
  final Object? error;

  double get score => stats?.totalPnl ?? double.negativeInfinity;
}

class _LeagueBody extends StatefulWidget {
  const _LeagueBody({required this.league, required this.members, required this.profile});

  final League league;
  final List<LeagueMember> members;
  final UserProfile profile;

  @override
  State<_LeagueBody> createState() => _LeagueBodyState();
}

class _LeagueBodyState extends State<_LeagueBody> {
  final Map<String, MemberResult> _results = {};
  bool _loading = false;
  DateTime? _updatedAt;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    // Re-render countdowns once a minute.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _LeagueBody old) {
    super.didUpdateWidget(old);
    final before = old.members.map((m) => m.uid).toSet();
    final after = widget.members.map((m) => m.uid).toSet();
    if (!before.containsAll(after)) _refresh(onlyMissing: true);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool onlyMissing = false}) async {
    if (_loading) return;
    final league = widget.league;
    final s = Services.of(context);
    final targets = widget.members.where((m) => !onlyMissing || !_results.containsKey(m.uid)).toList();
    if (targets.isEmpty) return;
    setState(() => _loading = true);

    if (league.status == LeagueStatus.upcoming) {
      // Nothing counts yet; show everyone at zero.
      for (final m in targets) {
        _results[m.uid] = MemberResult(m,
            stats: TraderStats(
              wallet: m.wallet,
              events: const [],
              openPositions: const [],
              includeUnrealized: false,
              computedAt: DateTime.now(),
            ));
      }
    } else {
      await s.dreamdex.marketsByPool(refresh: true).catchError((_) => <String, PerpMarket>{});
      final computed = await Future.wait(targets.map((m) async {
        try {
          final st = await s.stats.compute(m.wallet, from: league.startAt, to: league.endAt);
          return MemberResult(m, stats: st);
        } catch (e) {
          return MemberResult(m, error: e);
        }
      }));
      for (final r in computed) {
        _results[r.member.uid] = r;
      }
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _updatedAt = DateTime.now();
    });
  }

  List<MemberResult> get _ranked {
    final list = widget.members.map((m) => _results[m.uid] ?? MemberResult(m)).toList();
    list.sort((a, b) {
      final c = b.score.compareTo(a.score);
      return c != 0 ? c : a.member.displayName.compareTo(b.member.displayName);
    });
    return list;
  }

  void _copyInvite() {
    final l = widget.league;
    final link = AppConfig.inviteLink(l.inviteCode);
    final text = StringBuffer('Join my dreamDEX perps league "${l.name}" on ${AppConfig.appName}. ')
      ..write(link != null ? 'Open $link (works in any browser) or use code ${l.inviteCode}' : 'Invite code: ${l.inviteCode}');
    Clipboard.setData(ClipboardData(text: text.toString()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite copied. Paste it in your group chat.')));
  }

  void _copyStandings() {
    final ranked = _ranked.where((r) => r.stats != null).toList();
    final buf = StringBuffer('🏆 ${widget.league.name} standings\n');
    for (var i = 0; i < ranked.length && i < 10; i++) {
      final r = ranked[i];
      final medal = switch (i) { 0 => '🥇', 1 => '🥈', 2 => '🥉', _ => '${i + 1}.' };
      buf.writeln('$medal ${r.member.displayName}: ${formatUsd(r.stats!.totalPnl, signed: true)} USDso');
    }
    buf.write('Traded on dreamDEX perps (Somnia testnet).');
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Standings copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final league = widget.league;
    final ranked = _ranked;
    final standings = RefreshIndicator(
      onRefresh: _refresh,
      child: _Standings(
        league: league,
        ranked: ranked,
        myUid: widget.profile.uid,
        loading: _loading,
        updatedAt: _updatedAt,
        onCopyInvite: _copyInvite,
      ),
    );
    final feed = RefreshIndicator(
      onRefresh: _refresh,
      child: _Feed(league: league, results: ranked, myUid: widget.profile.uid, loading: _loading),
    );
    final actions = [
      IconButton(tooltip: 'Copy standings', onPressed: _copyStandings, icon: const Icon(Icons.ios_share_rounded)),
      IconButton(
        tooltip: 'Refresh',
        onPressed: _loading ? null : () => _refresh(),
        icon: _loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.refresh_rounded),
      ),
    ];

    // Web, desktop and tablets: standings and the trades feed side by side.
    if (MediaQuery.sizeOf(context).width >= 1100) {
      return Scaffold(
        appBar: AppBar(title: Text(league.name), actions: actions),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 5, child: standings),
            const VerticalDivider(width: 1),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Text('Trades', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  Expanded(child: feed),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(league.name),
          actions: actions,
          bottom: const TabBar(tabs: [Tab(text: 'Standings'), Tab(text: 'Trades')]),
        ),
        body: TabBarView(children: [standings, feed]),
      ),
    );
  }
}

class _Standings extends StatelessWidget {
  const _Standings({
    required this.league,
    required this.ranked,
    required this.myUid,
    required this.loading,
    required this.updatedAt,
    required this.onCopyInvite,
  });

  final League league;
  final List<MemberResult> ranked;
  final String myUid;
  final bool loading;
  final DateTime? updatedAt;
  final VoidCallback onCopyInvite;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final status = league.statusAt(now);
    final total = league.endAt.difference(league.startAt).inSeconds;
    final elapsed = now.difference(league.startAt).inSeconds;
    final double progress = total <= 0 ? 0.0 : (elapsed / total).clamp(0.0, 1.0).toDouble();

    return ResponsiveListView(
      physics: const AlwaysScrollableScrollPhysics(),
      top: 16,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusChip(status),
                    const Spacer(),
                    Text(
                      switch (status) {
                        LeagueStatus.live => 'Ends in ${formatDuration(league.endAt.difference(now))}',
                        LeagueStatus.upcoming => 'Starts in ${formatDuration(league.startAt.difference(now))}',
                        LeagueStatus.ended => 'Final results',
                      },
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: status == LeagueStatus.upcoming ? 0 : progress,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceHigh,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 8),
                Text('${formatDate(league.startAt)}  →  ${formatDate(league.endAt)}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onCopyInvite,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Text('Code ', style: TextStyle(color: AppColors.muted)),
                              Text(league.inviteCode,
                                  style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 3)),
                              const Spacer(),
                              const Icon(Icons.copy_rounded, size: 18, color: AppColors.muted),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.tonalIcon(
                      onPressed: () => launchUrl(Uri.parse(AppConfig.dreamDexAppUrl), mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.bolt_rounded),
                      label: const Text('Trade'),
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (status == LeagueStatus.upcoming)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Trades before the start don\'t count. Invite your people now.',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        if (status != LeagueStatus.upcoming && ranked.length >= 2 && ranked[0].stats != null)
          _Podium(ranked: ranked.take(3).toList(), ended: status == LeagueStatus.ended),
        SectionHeader(
          'Standings',
          trailing: updatedAt == null
              ? null
              : Text('Updated ${timeAgo(updatedAt!)}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ),
        for (var i = 0; i < ranked.length; i++) ...[
          _StandingRow(
            rank: i + 1,
            result: ranked[i],
            isMe: ranked[i].member.uid == myUid,
            loading: loading && ranked[i].stats == null,
            league: league,
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        const Text(
          'Score: realized P&L on closed trades during the league + unrealized P&L on open positions while live. '
          'Price P&L only; fees and funding are not included. Computed live from public dreamDEX indexer data.',
          style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.ranked, required this.ended});

  final List<MemberResult> ranked;
  final bool ended;

  @override
  Widget build(BuildContext context) {
    final leader = ranked.first;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.gold.withValues(alpha: 0.18), AppColors.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Text('🏆', style: TextStyle(fontSize: 34)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ended ? 'Champion' : 'Leading', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(leader.member.displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            PnlText(leader.stats!.totalPnl, size: 17),
          ],
        ),
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({
    required this.rank,
    required this.result,
    required this.isMe,
    required this.loading,
    required this.league,
  });

  final int rank;
  final MemberResult result;
  final bool isMe;
  final bool loading;
  final League league;

  @override
  Widget build(BuildContext context) {
    final st = result.stats;
    final rankColor = switch (rank) {
      1 => AppColors.gold,
      2 => AppColors.silver,
      3 => AppColors.bronze,
      _ => AppColors.muted,
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isMe ? AppColors.accent.withValues(alpha: 0.6) : AppColors.border),
      ),
      child: InkWell(
        onTap: st == null
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MemberProfileScreen(member: result.member, stats: st, league: league),
                )),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text('$rank', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: rankColor)),
              ),
              TraderAvatar(name: result.member.displayName, wallet: result.member.wallet),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(result.member.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 6),
                          const Text('YOU', style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w800)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      st == null
                          ? shortAddress(result.member.wallet)
                          : '${st.wins}/${st.closedTrades} wins · ${st.openPositions.length} open',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (st != null) ...[
                Sparkline(values: st.equityCurve),
                const SizedBox(width: 12),
              ],
              SizedBox(
                width: 96,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : result.error != null
                          ? const Tooltip(
                              message: 'Could not load this trader. Pull to retry.',
                              child: Icon(Icons.error_outline_rounded, color: AppColors.down),
                            )
                          : st == null
                              ? const Text('—', style: TextStyle(color: AppColors.muted))
                              : PnlText(st.totalPnl, suffix: '', size: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feed extends StatefulWidget {
  const _Feed({required this.league, required this.results, required this.myUid, required this.loading});

  final League league;
  final List<MemberResult> results;
  final String myUid;
  final bool loading;

  @override
  State<_Feed> createState() => _FeedState();
}

class _FeedState extends State<_Feed> {
  bool _closesOnly = false;

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    final items = <(LeagueMember, TradeEvent)>[];
    for (final r in widget.results) {
      final st = r.stats;
      if (st == null) continue;
      for (final e in st.events) {
        if (_closesOnly && !e.realizes) continue;
        items.add((r.member, e));
      }
    }
    items.sort((a, b) => b.$2.timestamp.compareTo(a.$2.timestamp));
    final shown = items.take(300).toList();

    return StreamBuilder<Map<String, TradeNote>>(
      stream: s.store.notes(widget.league.id),
      builder: (context, noteSnap) {
        final notes = noteSnap.data ?? const <String, TradeNote>{};
        return ResponsiveListView(
          physics: const AlwaysScrollableScrollPhysics(),
          top: 12,
          children: [
            Row(
              children: [
                ChoiceChip(label: const Text('All'), selected: !_closesOnly, onSelected: (_) => setState(() => _closesOnly = false)),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Closed trades'), selected: _closesOnly, onSelected: (_) => setState(() => _closesOnly = true)),
              ],
            ),
            const SizedBox(height: 12),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: widget.loading
                    ? const Center(child: CircularProgressIndicator())
                    : const EmptyState(
                        icon: Icons.receipt_long_rounded,
                        title: 'No trades yet',
                        message: 'When anyone in the league opens or closes a dreamDEX perp, it shows up here.',
                      ),
              ),
            for (final (member, e) in shown) ...[
              TradeTile(
                event: e,
                member: member,
                note: notes[TradeNote.docId(e.id, member.uid)],
                canNote: member.uid == widget.myUid,
                onEditNote: member.uid == widget.myUid
                    ? () => showNoteSheet(context, leagueId: widget.league.id, uid: widget.myUid, event: e,
                        existing: notes[TradeNote.docId(e.id, member.uid)])
                    : null,
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

/// Bottom sheet for writing a note on one of your own trades.
Future<void> showNoteSheet(
  BuildContext context, {
  required String leagueId,
  required String uid,
  required TradeEvent event,
  TradeNote? existing,
}) async {
  final s = Services.of(context);
  final controller = TextEditingController(text: existing?.text ?? '');
  final messenger = ScaffoldMessenger.of(context);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Why did you ${event.verb.split(' ').first} ${event.symbol}?',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Your league sees this next to the trade.', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 280,
              maxLines: 4,
              minLines: 2,
              decoration: const InputDecoration(hintText: 'Breakout above resistance, stop under the range low…'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (existing != null)
                  TextButton(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      try {
                        await s.store.deleteNote(leagueId: leagueId, uid: uid, eventId: event.id);
                      } catch (e) {
                        messenger.showSnackBar(SnackBar(content: Text('Could not delete: $e')));
                      }
                    },
                    child: const Text('Delete', style: TextStyle(color: AppColors.down)),
                  ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(120, 46)),
                  onPressed: () async {
                    final text = controller.text.trim();
                    if (text.isEmpty) return;
                    Navigator.of(ctx).pop();
                    try {
                      await s.store.saveNote(leagueId: leagueId, uid: uid, eventId: event.id, text: text);
                    } catch (e) {
                      messenger.showSnackBar(SnackBar(content: Text('Could not save note: $e')));
                    }
                  },
                  child: const Text('Post'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
  // Dispose after the sheet's exit animation so the field never touches a
  // disposed controller.
  Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
}

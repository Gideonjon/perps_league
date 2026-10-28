import 'package:flutter/material.dart';

import '../config.dart';
import '../core/invite.dart';
import '../data/league_models.dart';
import '../theme.dart';
import '../widgets/logo.dart';
import 'join_league_screen.dart';
import 'league_detail_screen.dart';
import 'leagues_screen.dart';
import 'markets_screen.dart';
import 'me_screen.dart';

/// Bottom navigation on phones; a side rail on tablets, desktop and web.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _destinations = [
    (Icons.emoji_events_outlined, Icons.emoji_events, 'Leagues'),
    (Icons.candlestick_chart_outlined, Icons.candlestick_chart, 'Markets'),
    (Icons.person_outline, Icons.person, 'Me'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingInvite());
  }

  /// Someone opened an invite link (`/?join=CODE`) in the browser.
  Future<void> _openPendingInvite() async {
    final code = PendingInvite.take();
    if (code == null || !mounted) return;
    final navigator = Navigator.of(context);
    final id = await navigator.push<String>(MaterialPageRoute(
      builder: (_) => JoinLeagueScreen(profile: widget.profile, initialCode: code),
    ));
    if (id == null || !mounted) return;
    navigator.push(MaterialPageRoute(
      builder: (_) => LeagueDetailScreen(leagueId: id, profile: widget.profile),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      LeaguesScreen(profile: widget.profile),
      const MarketsScreen(),
      MeScreen(profile: widget.profile),
    ];
    final body = IndexedStack(index: _index, children: pages);
    final wide = MediaQuery.sizeOf(context).width >= AppConfig.wideBreakpoint;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: AppColors.surface,
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              indicatorColor: AppColors.accent.withValues(alpha: 0.18),
              leading: const Padding(
                padding: EdgeInsets.only(top: 12, bottom: 20),
                child: LogoMark(size: 40, background: AppColors.surface),
              ),
              destinations: [
                for (final (icon, selected, label) in _destinations)
                  NavigationRailDestination(
                    icon: Icon(icon),
                    selectedIcon: Icon(selected),
                    label: Text(label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final (icon, selected, label) in _destinations)
            NavigationDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: label),
        ],
      ),
    );
  }
}

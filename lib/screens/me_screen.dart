import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/league_models.dart';
import '../data/stats.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/trader_summary.dart';
import 'link_wallet_screen.dart';

/// Your own performance over a rolling window, independent of any league.
class MeScreen extends StatefulWidget {
  const MeScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  static const _windows = <(String, int)>[('24h', 1), ('7d', 7), ('30d', 30)];
  int _days = 7;
  Future<TraderStats>? _future;
  String? _loadedWallet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_future == null || _loadedWallet != widget.profile.wallet) _load();
  }

  @override
  void didUpdateWidget(covariant MeScreen old) {
    super.didUpdateWidget(old);
    if (old.profile.wallet != widget.profile.wallet) _load();
  }

  void _load() {
    final now = DateTime.now();
    _loadedWallet = widget.profile.wallet;
    _future = Services.of(context).stats.compute(
          widget.profile.wallet,
          from: now.subtract(Duration(days: _days)),
          // A window ending in the future counts open positions as unrealized.
          to: now.add(const Duration(minutes: 5)),
        );
  }

  Future<void> _refresh() async {
    setState(_load);
    try {
      await _future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Me'),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => LinkWalletScreen(
                    uid: p.uid,
                    initialName: p.displayName,
                    initialWallet: p.wallet,
                    editing: true,
                  ),
                ));
              } else if (v == 'signout') {
                Services.of(context).auth.signOut();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit profile')),
              PopupMenuItem(value: 'signout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ResponsiveListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Row(
              children: [
                TraderAvatar(name: p.displayName, wallet: p.wallet, radius: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: p.wallet));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address copied')));
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AddressText(p.wallet),
                            const SizedBox(width: 4),
                            const Icon(Icons.copy_rounded, size: 13, color: AppColors.muted),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final (label, d) in _windows)
                  ChoiceChip(
                    label: Text(label),
                    selected: _days == d,
                    onSelected: (_) => setState(() {
                      _days = d;
                      _load();
                    }),
                  ),
              ],
            ),
            FutureBuilder<TraderStats>(
              future: _future,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: ErrorRetry(error: snap.error!, onRetry: _refresh),
                  );
                }
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return TraderSummary(stats: snap.data!);
              },
            ),
          ],
        ),
      ),
    );
  }
}

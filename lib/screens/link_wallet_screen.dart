import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../core/format.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Onboarding (and later, profile editing): a display name and the wallet
/// the user trades with on dreamDEX testnet.
class LinkWalletScreen extends StatefulWidget {
  const LinkWalletScreen({
    super.key,
    required this.uid,
    this.initialName = '',
    this.initialWallet = '',
    this.editing = false,
  });

  final String uid;
  final String initialName;
  final String initialWallet;
  final bool editing;

  @override
  State<LinkWalletScreen> createState() => _LinkWalletScreenState();
}

class _LinkWalletScreenState extends State<LinkWalletScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  late final _wallet = TextEditingController(text: widget.initialWallet);
  bool _busy = false;
  bool _checking = false;
  String? _checkResult;
  bool _checkOk = false;

  @override
  void dispose() {
    _name.dispose();
    _wallet.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final w = _wallet.text.trim();
    if (!isValidWallet(w)) {
      setState(() {
        _checkResult = 'Enter a full 0x address (42 characters) first.';
        _checkOk = false;
      });
      return;
    }
    setState(() {
      _checking = true;
      _checkResult = null;
    });
    final repo = Services.of(context).dreamdex;
    try {
      final now = DateTime.now();
      final results = await Future.wait([
        repo.tradeEvents(w, from: now.subtract(const Duration(days: 30)), to: now, maxRows: 1000),
        repo.openPositions(w),
      ]);
      final events = results[0] as List;
      final positions = results[1] as List;
      setState(() {
        _checkOk = true;
        _checkResult = events.isEmpty && positions.isEmpty
            ? 'No dreamDEX perps activity in the last 30 days. That\'s fine: it will show up as soon as you trade.'
            : 'Found ${events.length} position updates in the last 30 days and ${positions.length} open position${positions.length == 1 ? '' : 's'}.';
      });
    } catch (e) {
      setState(() {
        _checkOk = false;
        _checkResult = e.toString();
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final s = Services.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await s.store.saveProfile(widget.uid, displayName: _name.text, wallet: _wallet.text);
      if (widget.editing) navigator.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing ? 'Edit profile' : 'Set up your trader profile'),
        actions: [
          if (!widget.editing)
            TextButton(
              onPressed: () => Services.of(context).auth.signOut(),
              child: const Text('Sign out'),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ResponsiveListView(
            maxWidth: 560,
            top: 20,
            children: [
              TextFormField(
                controller: _name,
                maxLength: 30,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Display name', hintText: 'What your league sees'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Pick a name' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _wallet,
                autocorrect: false,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'dreamDEX testnet wallet',
                  hintText: '0x…',
                ),
                validator: (v) => (v == null || !isValidWallet(v)) ? 'Enter a valid 0x address' : null,
                onChanged: (_) {
                  if (_checkResult != null) setState(() => _checkResult = null);
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Use the address of the account you trade perps with on dreamDEX testnet. '
                'Your rank is computed from its public on-chain trades. '
                'Only the address is stored: never paste a private key or seed phrase anywhere.',
                style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _checking ? null : _check,
                icon: _checking
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.travel_explore_rounded),
                label: const Text('Check wallet on dreamDEX'),
              ),
              if (_checkResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: (_checkOk ? AppColors.up : AppColors.down).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_checkResult!, style: const TextStyle(height: 1.4)),
                ),
              ],
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Text(widget.editing ? 'Save' : 'Continue'),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(AppConfig.dreamDexAppUrl), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('No account yet? Open dreamDEX testnet'),
              ),
              if (widget.editing) ...[
                const SizedBox(height: 8),
                const Text(
                  'Leagues you already joined keep the wallet you joined with.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/league_models.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets/common.dart';

class JoinLeagueScreen extends StatefulWidget {
  const JoinLeagueScreen({super.key, required this.profile, this.initialCode});

  final UserProfile profile;

  /// Pre-filled from an invite link.
  final String? initialCode;

  @override
  State<JoinLeagueScreen> createState() => _JoinLeagueScreenState();
}

class _JoinLeagueScreenState extends State<JoinLeagueScreen> {
  late final _code = TextEditingController(text: widget.initialCode ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _code.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Invite codes are 6 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    try {
      final id = await Services.of(context).store.joinLeague(me: widget.profile, code: code);
      navigator.pop(id);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim().toUpperCase() ?? '';
    final match = RegExp(r'[A-Z2-9]{6}').firstMatch(text);
    if (match != null) setState(() => _code.text = match.group(0)!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join a league')),
      body: SafeArea(
        child: ResponsiveListView(
          maxWidth: 480,
          top: 20,
          children: [
            Text(
              widget.initialCode != null
                  ? 'You were invited to a league. Check the code and tap Join.'
                  : 'Enter the 6-character code your league owner shared.',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _code,
              autofocus: widget.initialCode == null,
              maxLength: 6,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                TextInputFormatter.withFunction(
                  (oldValue, newValue) => newValue.copyWith(text: newValue.text.toUpperCase()),
                ),
              ],
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 10),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'ABC123',
                suffixIcon: IconButton(onPressed: _paste, icon: const Icon(Icons.content_paste_rounded)),
              ),
              onSubmitted: (_) => _join(),
            ),
            const SizedBox(height: 12),
            Text(
              'You will join with ${widget.profile.wallet.substring(0, 8)}… as ${widget.profile.displayName}.',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.down)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _join,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Join league'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../data/league_models.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets/common.dart';

class CreateLeagueScreen extends StatefulWidget {
  const CreateLeagueScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<CreateLeagueScreen> createState() => _CreateLeagueScreenState();
}

class _CreateLeagueScreenState extends State<CreateLeagueScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  Duration _length = const Duration(days: 7);
  bool _startNow = true;
  bool _busy = false;

  static const _lengths = <(String, Duration)>[
    ('1 day', Duration(days: 1)),
    ('3 days', Duration(days: 3)),
    ('1 week', Duration(days: 7)),
    ('2 weeks', Duration(days: 14)),
  ];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  DateTime get _start {
    final now = DateTime.now();
    if (_startNow) return now;
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 9);
    return tomorrow;
  }

  Future<void> _create() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final s = Services.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final start = _start;
      final id = await s.store.createLeague(
        owner: widget.profile,
        name: _name.text,
        startAt: start,
        endAt: start.add(_length),
      );
      navigator.pop(id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not create league: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = _start;
    return Scaffold(
      appBar: AppBar(title: const Text('New league')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ResponsiveListView(
            maxWidth: 560,
            top: 20,
            children: [
              TextFormField(
                controller: _name,
                maxLength: 40,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'League name', hintText: 'e.g. UniUyo GDG Perps Cup'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Give your league a name' : null,
              ),
              const SizedBox(height: 16),
              const Text('How long?', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, d) in _lengths)
                    ChoiceChip(
                      label: Text(label),
                      selected: _length == d,
                      onSelected: (_) => setState(() => _length = d),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Starts', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Right now')),
                  ButtonSegment(value: false, label: Text('Tomorrow 9:00')),
                ],
                selected: {_startNow},
                onSelectionChanged: (v) => setState(() => _startNow = v.first),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${formatDate(start)}  →  ${formatDate(start.add(_length))}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text(
                      'Score = realized P&L from trades closed during the league, plus unrealized P&L on '
                      'open positions while it is live. All numbers come from public dreamDEX testnet data.',
                      style: TextStyle(color: AppColors.muted, height: 1.4, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _busy ? null : _create,
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Create league'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

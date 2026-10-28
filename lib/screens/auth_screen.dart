import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/invite.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets/logo.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String _friendly(FirebaseAuthException e) => switch (e.code) {
        'email-already-in-use' => 'An account already exists for that email. Sign in instead.',
        'invalid-email' => 'That email address looks wrong.',
        'weak-password' => 'Use at least 6 characters for your password.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Email or password is incorrect.',
        'too-many-requests' => 'Too many attempts. Wait a minute and try again.',
        'network-request-failed' => 'No connection. Check your internet and retry.',
        _ => e.message ?? 'Sign-in failed (${e.code}).',
      };

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = Services.of(context).auth;
    try {
      if (_signUp) {
        await auth.createUserWithEmailAndPassword(email: _email.text.trim(), password: _password.text);
      } else {
        await auth.signInWithEmailAndPassword(email: _email.text.trim(), password: _password.text);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email above first.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Services.of(context).auth.sendPasswordResetEmail(email: email);
      messenger.showSnackBar(const SnackBar(content: Text('Password reset email sent.')));
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendly(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: LogoMark(size: 88)),
                    const SizedBox(height: 16),
                    const Text.rich(
                      TextSpan(children: [
                        TextSpan(text: 'Perps '),
                        TextSpan(text: 'League', style: TextStyle(color: AppColors.accent)),
                      ]),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Trading leagues for dreamDEX perps.\nReal testnet P&L. Bragging rights only.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, height: 1.4),
                    ),
                    if (PendingInvite.peek != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'You were invited to league ${PendingInvite.peek}. '
                          'Create an account or sign in and you\'ll go straight to it.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(height: 1.4),
                        ),
                      ),
                    ],
                    const SizedBox(height: 36),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppColors.down)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                          : Text(_signUp ? 'Create account' : 'Sign in'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : () => setState(() => _signUp = !_signUp),
                      child: Text(_signUp ? 'Already have an account? Sign in' : 'New here? Create an account'),
                    ),
                    if (!_signUp)
                      TextButton(
                        onPressed: _busy ? null : _resetPassword,
                        child: const Text('Forgot password?', style: TextStyle(color: AppColors.muted)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

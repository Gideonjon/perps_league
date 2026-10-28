import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/league_models.dart';
import '../services.dart';
import 'auth_screen.dart';
import 'home_shell.dart';
import 'link_wallet_screen.dart';

/// Signed out → sign-in. Signed in without a wallet → onboarding. Else home.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    return StreamBuilder<User?>(
      stream: s.auth.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const _Splash();
        }
        final user = authSnap.data;
        if (user == null) return const AuthScreen();
        return StreamBuilder<UserProfile?>(
          key: ValueKey(user.uid),
          stream: s.store.profile(user.uid),
          builder: (context, profSnap) {
            if (profSnap.hasError) {
              return Scaffold(body: Center(child: Text('Could not load profile: ${profSnap.error}')));
            }
            if (!profSnap.hasData && profSnap.connectionState == ConnectionState.waiting) {
              return const _Splash();
            }
            final profile = profSnap.data;
            if (profile == null || profile.wallet.isEmpty) {
              return LinkWalletScreen(uid: user.uid, initialName: user.displayName ?? '');
            }
            return HomeShell(profile: profile);
          },
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

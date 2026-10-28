import 'package:flutter/foundation.dart';

/// Network and app settings. Override any of these at build time with
/// `--dart-define`, e.g.
///
///   flutter build web --dart-define=APP_URL=https://perps-league.web.app
class AppConfig {
  AppConfig._();

  static const String appName = 'Perps League';

  /// dreamDEX indexer (Hasura GraphQL) for the Hideki perps network.
  /// Override with `--dart-define=INDEXER_URL=...` to route through a CORS
  /// proxy if the browser build is ever blocked.
  static const String indexerUrl = String.fromEnvironment(
    'INDEXER_URL',
    defaultValue: 'https://hideki-dev.smk.somnia.host/v1/graphql',
  );

  /// Somnia Tokyo testnet (Hideki).
  static const int chainId = 50383;

  /// Where users actually place trades.
  static const String dreamDexAppUrl = 'https://app.testnet.dreamdex.io';

  /// Public URL of the hosted web app (Firebase Hosting). Used to build
  /// invite links from the Android and iOS apps. On the web the current
  /// origin is used instead, so this can stay empty there.
  static const String _appUrl = 'https://perpsleague.web.app';

  /// Hard cap on league size: keeps the live leaderboard to a handful of
  /// indexer calls and matches the limit in firestore.rules.
  static const int maxLeagueMembers = 50;

  /// Width above which the app switches to its desktop / tablet layout.
  static const double wideBreakpoint = 840;

  /// Shareable link that opens the web app straight onto the join screen,
  /// or null when no web URL is known.
  static String? inviteLink(String code) {
    final base = kIsWeb ? Uri.base.origin : _appUrl;
    if (base.isEmpty) return null;
    final trimmed = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$trimmed/?join=$code';
  }
}

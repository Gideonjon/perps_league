# Perps League

**Trading leagues for dreamDEX perps, on Android, iOS and the web.** Create a league, share a 6-character code, and compete with friends on real P&L from dreamDEX perpetuals on Somnia's Tokyo testnet (Hideki, chain 50383). Standings, a live trade feed, trade notes, and per-trader breakdowns, all computed from public on-chain data.

Built for the dreamDEX Perps Builder Bounty (MVP track).

## Why it exists

Paper trading alone is lonely and easy to quit. Leagues give people a reason to open dreamDEX every day: a scoreboard, a deadline, and friends watching. Every number in the app comes from the dreamDEX indexer, so scores can't be self-reported or faked.

## Features

- **Leagues:** create (1 day to 2 weeks, start now or tomorrow), join with an invite code, copy invite text for group chats.
- **Live standings:** rank by total P&L (realized on trades closed during the league + unrealized on open positions while live), win rate, open positions, equity sparkline, podium.
- **Trade feed:** every open, add, trim, close and flip by league members, newest first, with "closed trades only" filter.
- **Trade notes:** members explain their own trades ("why I shorted SOL"); the league sees the note on the trade.
- **Trader profiles:** total/realized/unrealized P&L, best and worst trade, favourite market, open positions with live mark, full trade history with tx hashes.
- **Markets:** all dreamDEX perp markets with mark price and funding; candlestick charts (5m to 1d), index price, open interest; one tap to trade on dreamDEX.
- **Me:** your own stats over 24h / 7d / 30d, independent of leagues.
- **Shareable standings:** copies a medal-formatted leaderboard for WhatsApp/X.

## How it works

```
Flutter app ──GraphQL (HTTPS)──► dreamDEX indexer (hideki-dev.smk.somnia.host)
     │                              Market, PerpPosition, PerpPositionChange, Candle
     └──Firebase Auth + Firestore (Spark/free plan)
            users, leagues, members, notes
```

- **No backend, no Cloud Functions.** Works on the free Firebase Spark plan.
- **Scores are never stored.** Each client computes every member's stats live from the indexer. Nothing goes stale and nobody can write a fake score.
- **Read-only on-chain.** Users trade in the dreamDEX app; Perps League only reads public data. No keys, no signing, no custody.
- **Indexer queries mirror the official SDK** (`@somnia-chain/markets-sdk@0.32.1`: `src/perp/state.ts`, `src/perp/history.ts`, `src/candles.ts`), selecting only columns the deployed indexer serves.
- **P&L source:** `PerpPositionChange.realizedPnl` per update (REDUCE / CLOSE / FLIP), so closed-trade results need no fill replay. Unrealized uses `PerpPosition` size and entry against the market's `markPrice`.
- **Units:** the indexer returns raw integer strings. Sizes ÷ 10^baseDecimals, prices and PnL ÷ 10^quoteDecimals, funding ÷ 1e18 (per funding window). `PerpPosition.entryPriceX18` is *not* 1e18-scaled despite its name.

### Firestore data model

| Path | Fields |
| --- | --- |
| `users/{uid}` | displayName, wallet (lowercase 0x) |
| `leagues/{id}` | name, inviteCode, ownerUid, startAt, endAt, memberUids[], wallets[], createdAt |
| `leagues/{id}/members/{uid}` | displayName, wallet, joinedAt |
| `leagues/{id}/notes/{eventId}_{uid}` | eventId, uid, text, createdAt |

`firestore.rules` enforces: you write only your own profile and notes; you can join a league only by adding yourself with your own wallet, once, before it ends, while it has room (max 50); a wallet can't be in the same league twice; note ids are bound to the author so nobody can annotate someone else's trade.

## Platforms

One Flutter codebase runs on **Android, iOS and the web**, all sharing the same Firebase project and the same leagues.

| | Android | iOS | Web |
| --- | --- | --- | --- |
| Layout | Bottom nav | Bottom nav | Side rail ≥ 840 px; standings + feed side by side ≥ 1100 px; phone layout on mobile browsers |
| Invite | Copy code (+ web link if `APP_URL` set) | Same | Link `/?join=CODE` opens straight to the join screen, through sign-up |
| Install | APK / Play | Xcode / TestFlight | Open the link; "Add to Home Screen" works (PWA manifest) |
| Icons | Adaptive icon | App icon | Favicon, PWA and maskable icons |

The web build is what you give judges: **no install, works on any phone or laptop**.

## Setup

Requires Flutter 3.29+, a Firebase project on the free Spark plan, and Xcode for iOS builds.

```bash
cd perps_league
dart run tool/setup.dart
```

`tool/setup.dart` creates the `android/`, `ios/` and `web/` folders (keeping the files in this repo), adds the Android INTERNET permission for release builds, sets Android minSdk 23 and iOS 13.0 (both required by Firebase), and generates app icons for all three platforms.

Then connect Firebase (this generates `lib/firebase_options.dart` with all three platform configs):

```bash
dart pub global activate flutterfire_cli
flutterfire configure --platforms=android,ios,web
```

In the Firebase console:
1. **Authentication → Sign-in method:** enable Email/Password.
2. **Firestore Database:** create a database (production mode).
3. **Rules:** deploy `firestore.rules` with `firebase deploy --only firestore:rules`, or paste the file into the console's Rules tab.

Run:

```bash
flutter test               # unit tests for unit conversion and P&L
flutter run -d chrome      # web
flutter run                # connected Android phone or iOS simulator
```

If a Firebase package version conflicts with your Flutter version, run `flutter pub upgrade --major-versions`.

## Deploy the web app (free)

Firebase Hosting is included in the Spark plan.

```bash
npm install -g firebase-tools   # once
firebase login
firebase use --add              # pick the same project flutterfire configured

flutter build web --release --dart-define=APP_URL=https://perpsleague.web.app
firebase deploy --only hosting
```

Your app is live at `https://<project-id>.web.app`. Hosting domains are authorized for Firebase Auth automatically.

Build the Android and iOS apps with the same `APP_URL` so invites copied on a phone carry a link anyone can open in a browser:

```bash
flutter build apk --release --dart-define=APP_URL=https://<project-id>.web.app
flutter build ipa --release --dart-define=APP_URL=https://<project-id>.web.app
```

### If the web build can't reach the indexer

Browsers only allow the call if the dreamDEX indexer sends CORS headers. Check this first: run `flutter run -d chrome` and open Markets. If markets load, you're fine. If the browser console shows a CORS error, put a small proxy in front of the indexer (for example a free Cloudflare Worker that forwards POSTs and adds `Access-Control-Allow-Origin`) and point the app at it, with no code changes:

```bash
flutter build web --dart-define=INDEXER_URL=https://<your-proxy>/v1/graphql
```

Android and iOS are unaffected; CORS only applies in browsers.

## Demo script (2 minutes)

1. On a phone, sign up, paste your dreamDEX testnet address, tap **Check wallet on dreamDEX** to show live activity.
2. Create "GDG UniUyo Perps Cup", 1 week, start now. Copy the invite.
3. On a laptop, open the invite link in a browser: sign up and land straight on the join screen. Show the wide layout with standings and trades side by side.
4. Open dreamDEX testnet, open and close an ETH-PERP position.
5. Pull to refresh: the trade appears in the feed, standings reorder, P&L updates.
6. Add a note to the trade. Open a rival's profile. Show Markets → ETH-PERP chart.
7. Copy standings and paste them into a chat.

## Feedback track

`feedback/` holds one Markdown file per issue found while building against the dreamDEX indexer and SDK, in the bounty's template. Each one is reproducible read-only, with no wallet:

```bash
dart run feedback/repro/repro.dart   # writes feedback/evidence/*.json
```

Commit the evidence files with the reports. If the script says an item didn't reproduce, delete that report before submitting.

## Limitations

- **Wallet ownership isn't proven.** Users paste an address; the rules stop the same wallet joining a league twice, but a signature check (WalletConnect `personal_sign`) is the next step.
- **Price P&L only.** Fees and funding are separate records on dreamDEX and aren't included in scores.
- **Unrealized P&L** counts open positions regardless of when they were opened, while the league is live.
- **Indexer lag:** the indexer trails chain head slightly, so a trade can take a few seconds to appear.
- **Large histories:** trade history is capped at 3,000 updates per member per league window.

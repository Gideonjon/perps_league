import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import 'data/dreamdex_repository.dart';
import 'data/firestore_repository.dart';
import 'data/stats.dart';

/// App-wide dependencies, provided once at the root.
class Services extends InheritedWidget {
  Services({super.key, required super.child})
      : auth = FirebaseAuth.instance,
        store = FirestoreRepository(),
        dreamdex = DreamDexRepository() {
    stats = StatsService(dreamdex);
  }

  final FirebaseAuth auth;
  final FirestoreRepository store;
  final DreamDexRepository dreamdex;
  late final StatsService stats;

  static Services of(BuildContext context) {
    final s = context.getInheritedWidgetOfExactType<Services>();
    assert(s != null, 'Services not found in widget tree');
    return s!;
  }

  @override
  bool updateShouldNotify(Services oldWidget) => false;
}

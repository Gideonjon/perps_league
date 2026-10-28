import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../config.dart';
import 'league_models.dart';

class LeagueException implements Exception {
  LeagueException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Users, leagues, members and trade notes in Cloud Firestore.
///
/// Built for the free Spark plan: no Cloud Functions. Scores are never stored;
/// every client computes them live from the dreamDEX indexer, so there is
/// nothing to fake and nothing that goes stale.
class FirestoreRepository {
  FirestoreRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _leagues => _db.collection('leagues');

  // ---------------------------------------------------------------- users

  Stream<UserProfile?> profile(String uid) => _users.doc(uid).snapshots().map(
        (s) => s.exists ? UserProfile.fromDoc(s) : null,
      );

  Future<void> saveProfile(String uid, {required String displayName, required String wallet}) {
    return _users.doc(uid).set({
      'displayName': displayName.trim(),
      'wallet': wallet.trim().toLowerCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // -------------------------------------------------------------- leagues

  Stream<List<League>> myLeagues(String uid) => _leagues
      .where('memberUids', arrayContains: uid)
      .snapshots()
      .map((q) {
        final list = q.docs.map(League.fromDoc).toList();
        // Live first, then upcoming, then ended; newest within each group.
        int rank(League l) => switch (l.status) {
              LeagueStatus.live => 0,
              LeagueStatus.upcoming => 1,
              LeagueStatus.ended => 2,
            };
        list.sort((a, b) {
          final r = rank(a).compareTo(rank(b));
          return r != 0 ? r : b.createdAt.compareTo(a.createdAt);
        });
        return list;
      });

  Stream<League?> league(String id) =>
      _leagues.doc(id).snapshots().map((s) => s.exists ? League.fromDoc(s) : null);

  Stream<List<LeagueMember>> members(String leagueId) => _leagues
      .doc(leagueId)
      .collection('members')
      .snapshots()
      .map((q) => q.docs.map(LeagueMember.fromDoc).toList());

  static const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String _newCode() {
    final r = Random.secure();
    return List.generate(6, (_) => _codeAlphabet[r.nextInt(_codeAlphabet.length)]).join();
  }

  Future<String> createLeague({
    required UserProfile owner,
    required String name,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    // Make a few attempts at a code nobody else is using.
    String code = _newCode();
    for (var i = 0; i < 4; i++) {
      final clash = await _leagues.where('inviteCode', isEqualTo: code).limit(1).get();
      if (clash.docs.isEmpty) break;
      code = _newCode();
    }

    final ref = _leagues.doc();
    final batch = _db.batch();
    batch.set(ref, {
      'name': name.trim(),
      'inviteCode': code,
      'ownerUid': owner.uid,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'memberUids': [owner.uid],
      'wallets': [owner.wallet],
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(ref.collection('members').doc(owner.uid), {
      'displayName': owner.displayName,
      'wallet': owner.wallet,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return ref.id;
  }

  /// Joins the league with [code]. Returns the league id.
  Future<String> joinLeague({required UserProfile me, required String code}) async {
    final normalized = code.trim().toUpperCase();
    final q = await _leagues.where('inviteCode', isEqualTo: normalized).limit(1).get();
    if (q.docs.isEmpty) throw LeagueException('No league found with code $normalized.');

    final doc = q.docs.first;
    final league = League.fromDoc(doc);
    if (league.memberUids.contains(me.uid)) return league.id;
    if (league.status == LeagueStatus.ended) {
      throw LeagueException('${league.name} has already ended.');
    }
    if (league.memberUids.length >= AppConfig.maxLeagueMembers) {
      throw LeagueException('${league.name} is full.');
    }
    final wallets = List<String>.from(doc.data()['wallets'] ?? const []);
    if (wallets.contains(me.wallet)) {
      throw LeagueException('That wallet is already in this league under another account.');
    }

    final batch = _db.batch();
    batch.update(doc.reference, {
      'memberUids': FieldValue.arrayUnion([me.uid]),
      'wallets': FieldValue.arrayUnion([me.wallet]),
    });
    batch.set(doc.reference.collection('members').doc(me.uid), {
      'displayName': me.displayName,
      'wallet': me.wallet,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw LeagueException('Could not join. The league may be full, ended, or already have your wallet.');
      }
      rethrow;
    }
    return league.id;
  }

  // ---------------------------------------------------------------- notes

  Stream<Map<String, TradeNote>> notes(String leagueId) => _leagues
      .doc(leagueId)
      .collection('notes')
      .snapshots()
      .map((q) => {for (final d in q.docs) d.id: TradeNote.fromDoc(d)});

  Future<void> saveNote({
    required String leagueId,
    required String uid,
    required String eventId,
    required String text,
  }) {
    final ref = _leagues.doc(leagueId).collection('notes').doc(TradeNote.docId(eventId, uid));
    return ref.set({
      'eventId': eventId,
      'uid': uid,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteNote({required String leagueId, required String uid, required String eventId}) {
    return _leagues.doc(leagueId).collection('notes').doc(TradeNote.docId(eventId, uid)).delete();
  }
}

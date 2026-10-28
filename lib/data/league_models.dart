import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  UserProfile({required this.uid, required this.displayName, required this.wallet});

  final String uid;
  final String displayName;

  /// Lowercased 0x address the user trades with on dreamDEX testnet.
  final String wallet;

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return UserProfile(
      uid: doc.id,
      displayName: (d['displayName'] ?? '').toString(),
      wallet: (d['wallet'] ?? '').toString(),
    );
  }
}

enum LeagueStatus { upcoming, live, ended }

class League {
  League({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.ownerUid,
    required this.startAt,
    required this.endAt,
    required this.memberUids,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String inviteCode;
  final String ownerUid;
  final DateTime startAt;
  final DateTime endAt;
  final List<String> memberUids;
  final DateTime createdAt;

  LeagueStatus statusAt(DateTime now) {
    if (now.isBefore(startAt)) return LeagueStatus.upcoming;
    if (now.isBefore(endAt)) return LeagueStatus.live;
    return LeagueStatus.ended;
  }

  LeagueStatus get status => statusAt(DateTime.now());

  factory League.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    DateTime ts(Object? v) => v is Timestamp ? v.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
    return League(
      id: doc.id,
      name: (d['name'] ?? 'League').toString(),
      inviteCode: (d['inviteCode'] ?? '').toString(),
      ownerUid: (d['ownerUid'] ?? '').toString(),
      startAt: ts(d['startAt']),
      endAt: ts(d['endAt']),
      memberUids: List<String>.from(d['memberUids'] ?? const []),
      createdAt: ts(d['createdAt']),
    );
  }
}

class LeagueMember {
  LeagueMember({
    required this.uid,
    required this.displayName,
    required this.wallet,
    required this.joinedAt,
  });

  final String uid;
  final String displayName;
  final String wallet;
  final DateTime joinedAt;

  factory LeagueMember.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    final j = d['joinedAt'];
    return LeagueMember(
      uid: doc.id,
      displayName: (d['displayName'] ?? 'Trader').toString(),
      wallet: (d['wallet'] ?? '').toString(),
      joinedAt: j is Timestamp ? j.toDate() : DateTime.now(),
    );
  }
}

/// A member's comment on one of their own trades, visible to the league.
class TradeNote {
  TradeNote({
    required this.eventId,
    required this.uid,
    required this.text,
    required this.createdAt,
  });

  final String eventId;
  final String uid;
  final String text;
  final DateTime createdAt;

  static String docId(String eventId, String uid) => '${eventId}_$uid';

  factory TradeNote.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    final c = d['createdAt'];
    return TradeNote(
      eventId: (d['eventId'] ?? '').toString(),
      uid: (d['uid'] ?? '').toString(),
      text: (d['text'] ?? '').toString(),
      createdAt: c is Timestamp ? c.toDate() : DateTime.now(),
    );
  }
}

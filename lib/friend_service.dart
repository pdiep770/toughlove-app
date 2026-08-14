import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendService {
  final _db = FirebaseFirestore.instance;

  String? get _myUid => FirebaseAuth.instance.currentUser?.uid;

  Future<String> sendFriendRequest(String friendCode) async {
    final myUid = _myUid;
    if (myUid == null) throw Exception('Not signed in');

    final query = await _db
        .collection('users')
        .where('friendCode', isEqualTo: friendCode.toUpperCase().trim())
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return 'No user found with that code';
    }

    final targetUid = query.docs.first.id;

    if (targetUid == myUid) {
      return "You can't add yourself";
    }

    final myDoc = await _db.collection('users').doc(myUid).get();
    final myFriends = List<String>.from(myDoc.data()?['friends'] ?? []);
    if (myFriends.contains(targetUid)) {
      return 'You are already friends';
    }

    final existing = await _db
        .collection('friendRequests')
        .where('fromUid', isEqualTo: myUid)
        .where('toUid', isEqualTo: targetUid)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existing.docs.isNotEmpty) {
      return 'Request already sent';
    }

    final myDisplayName = myDoc.data()?['displayName'] ?? 'Someone';

    await _db.collection('friendRequests').add({
      'fromUid': myUid,
      'fromDisplayName': myDisplayName,
      'toUid': targetUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return 'Friend request sent!';
  }

  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    final myUid = _myUid;
    if (myUid == null) return [];

    final query = await _db
        .collection('friendRequests')
        .where('toUid', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .get();

    return query.docs.map((doc) => {'requestId': doc.id, ...doc.data()}).toList();
  }

  Future<void> acceptRequest(String requestId, String fromUid) async {
    final myUid = _myUid;
    if (myUid == null) throw Exception('Not signed in');

    await _db.collection('users').doc(myUid).update({
      'friends': FieldValue.arrayUnion([fromUid]),
    });
    await _db.collection('users').doc(fromUid).update({
      'friends': FieldValue.arrayUnion([myUid]),
    });
    await _db.collection('friendRequests').doc(requestId).update({
      'status': 'accepted',
    });
  }

  Future<void> declineRequest(String requestId) async {
    await _db.collection('friendRequests').doc(requestId).update({
      'status': 'declined',
    });
  }

  Future<List<Map<String, dynamic>>> getFriends() async {
    final myUid = _myUid;
    if (myUid == null) return [];

    final myDoc = await _db.collection('users').doc(myUid).get();
    final friendUids = List<String>.from(myDoc.data()?['friends'] ?? []);
    if (friendUids.isEmpty) return [];

    final friends = <Map<String, dynamic>>[];
    for (final uid in friendUids) {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        friends.add({'uid': uid, 'displayName': doc.data()?['displayName'] ?? 'Unknown'});
      }
    }
    return friends;
  }
}
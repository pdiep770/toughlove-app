import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final _db = FirebaseFirestore.instance;

  String? get _myUid => FirebaseAuth.instance.currentUser?.uid;

  // Deterministic conversation ID from two UIDs, so both people always land
  // on the same conversation regardless of who opens it first
  String _conversationId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<String> getOrCreateConversation(String friendUid) async {
    final myUid = _myUid;
    if (myUid == null) throw Exception('Not signed in');

    final convoId = _conversationId(myUid, friendUid);
    final convoRef = _db.collection('conversations').doc(convoId);
    final convoDoc = await convoRef.get();

    if (!convoDoc.exists) {
      await convoRef.set({
        'participants': [myUid, friendUid],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    }

    return convoId;
  }

  Future<void> sendMessage(String conversationId, String text) async {
    final myUid = _myUid;
    if (myUid == null) throw Exception('Not signed in');
    if (text.trim().isEmpty) return;

    final convoRef = _db.collection('conversations').doc(conversationId);

    await convoRef.collection('messages').add({
      'senderUid': myUid,
      'text': text.trim(),
      'sentAt': FieldValue.serverTimestamp(),
    });

    await convoRef.update({
      'lastMessage': text.trim(),
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getMessages(String conversationId) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .snapshots();
  }
}
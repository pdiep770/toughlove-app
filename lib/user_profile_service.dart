import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileService {
  final _db=FirebaseFirestore.instance;

  String _generateFriendCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<Map<String, dynamic>?> getProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;

    final data = doc.data();
    if (data ==null || data['displayName'] == null) return null;
    
    return data;
  }
    Future<void> createProfile(String displayName) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('No signed-in user found');

    final friendCode = _generateFriendCode();

    await _db.collection('users').doc(uid).set({
      'displayName': displayName,
      'friendCode': friendCode,
    }, SetOptions(merge: true));
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_service.dart';
import 'streak_logic.dart';

class StreakService {
  final _db = FirebaseFirestore.instance;
  final _chatService = ChatService();

  String? get _myUid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> touchStreakWithFriend(String friendUid) async {
    final myUid = _myUid;
    if (myUid == null) return;

    // Goes through ChatService so the conversation doc -- if this is the pair's
    // very first activity -- gets created with its normal full field set
    // (createdAt/lastMessage/lastMessageAt included), not a partial doc that
    // getOrCreateConversation would later skip filling in because it already exists.
    final convoId = await _chatService.getOrCreateConversation(friendUid);
    final convoRef = _db.collection('conversations').doc(convoId);

    final today = dateKey(DateTime.now());
    final yesterday = dateKey(DateTime.now().subtract(const Duration(days: 1)));

    await _db.runTransaction((tx) async {
      final snap = await tx.get(convoRef);
      final data = snap.data() ?? {};
      final currentStreak = (data['streakCount'] as num?)?.toInt() ?? 0;
      final lastStreakDate = data['lastStreakDate'] as String?;

      if (lastStreakDate == today) {
        return; // already touched today (workout log and chat message both landed), nothing to write
      }

      final nextStreak = computeNextStreak(currentStreak, lastStreakDate, today, yesterday);
      tx.update(convoRef, {
        'streakCount': nextStreak,
        'lastStreakDate': today,
      });
    });
  }

  Future<void> touchStreakWithAllFriends(List<String> friendUids) async {
    for (final uid in friendUids) {
      await touchStreakWithFriend(uid);
    }
  }

  Future<int> getStreakWith(String friendUid) async {
    final myUid = _myUid;
    if (myUid == null) return 0;

    final convoId = _chatService.conversationId(myUid, friendUid);
    final doc = await _db.collection('conversations').doc(convoId).get();
    if (!doc.exists) return 0;

    final data = doc.data()!;
    final lastStreakDate = data['lastStreakDate'] as String?;
    final today = dateKey(DateTime.now());
    final yesterday = dateKey(DateTime.now().subtract(const Duration(days: 1)));

    if (!isStreakAlive(lastStreakDate, today, yesterday)) return 0;
    return (data['streakCount'] as num?)?.toInt() ?? 0;
  }
}

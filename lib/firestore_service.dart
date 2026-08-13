import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'workout_plan.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  Future<void> saveIntakeAndPlan({
    required String experienceLevel,
    required int daysPerWeek,
    required String goal,
    required String equipmentAccess,
    required String injuries,
    required WorkoutPlan plan,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('No signed-in user found');
    }

    await _db.collection('users').doc(uid).set({
      'experienceLevel': experienceLevel,
      'daysPerWeek': daysPerWeek,
      'goal': goal,
      'equipmentAccess': equipmentAccess,
      'injuries': injuries,
      'createdAt': FieldValue.serverTimestamp(),
      'currentPlan': {
        'splitType': plan.splitType,
        'days': plan.days.map((day) => {
              'dayLabel': day.dayLabel,
              'exercises': day.exercises.map((ex) => {
                    'name': ex.name,
                    'sets': ex.sets,
                    'repsLow': ex.repsLow,
                    'repsHigh': ex.repsHigh,
                    'weight': ex.weight,
                  }).toList(),
            }).toList(),
      },
    });
  }
}
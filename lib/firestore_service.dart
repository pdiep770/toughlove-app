import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'workout_plan.dart';
import 'exercise.dart';

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
    }, SetOptions(merge: true));
  }

  Future<void> saveWorkoutLog({
    required String dayLabel,
    required List<Exercise> exercises,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('No signed-in user found');
    }

    await _db.collection('users').doc(uid).collection('logs').add({
      'dayLabel': dayLabel,
      'loggedAt': FieldValue.serverTimestamp(),
      'exercises': exercises.map((ex) => {
            'name': ex.name,
            'sets': ex.sets,
            'repsLow': ex.repsLow,
            'repsHigh': ex.repsHigh,
            'weight': ex.weight,
          }).toList(),
    });
  }

  Future<void> updateDayExercises({
    required String dayLabel,
    required List<Exercise> exercises,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('No signed-in user found');
    }

    final docRef = _db.collection('users').doc(uid);
    final snapshot = await docRef.get();
    final currentPlan = snapshot.data()?['currentPlan'];
    if (currentPlan == null) return;

    final days = List<Map<String, dynamic>>.from(
      (currentPlan['days'] as List).map((d) => Map<String, dynamic>.from(d)),
    );
    final dayIndex = days.indexWhere((d) => d['dayLabel'] == dayLabel);
    if (dayIndex == -1) return;

    days[dayIndex] = {
      'dayLabel': dayLabel,
      'exercises': exercises.map((ex) => {
            'name': ex.name,
            'sets': ex.sets,
            'repsLow': ex.repsLow,
            'repsHigh': ex.repsHigh,
            'weight': ex.weight,
          }).toList(),
    };

    await docRef.set({
      'currentPlan': {
        'splitType': currentPlan['splitType'],
        'days': days,
      },
    }, SetOptions(merge: true));
  }
}
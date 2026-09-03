import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'workout_plan.dart';
import 'exercise.dart';
import 'training_maxes.dart';

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
      // A fresh intake re-seeds training maxes from whatever 1RM was just entered —
      // deliberately overwrites rather than merges, since a fresh entry represents
      // current truth. Always written (even all-null) so an unset lift's stale value
      // doesn't linger from a previous intake.
      'trainingMaxes': (plan.trainingMaxes ?? const TrainingMaxes()).toJson(),
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

  Future<List<Map<String, dynamic>>> getLogs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('No signed-in user found');
    }

    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('logs')
        .orderBy('loggedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<TrainingMaxes?> getTrainingMaxes() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('No signed-in user found');
    }

    final snapshot = await _db.collection('users').doc(uid).get();
    final raw = snapshot.data()?['trainingMaxes'];
    if (raw == null) return null;
    return TrainingMaxes.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<void> updateTrainingMaxes(TrainingMaxes updates) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('No signed-in user found');
    }

    // Read-merge-write client-side rather than relying on Firestore's own nested-map
    // merge behavior, so the correctness here doesn't depend on getting that subtle
    // and easy to misremember (this project has already been bitten once by a merge
    // edge case wiping out sibling fields -- see the SetOptions(merge:true) note above).
    final current = await getTrainingMaxes();
    final merged = (current ?? const TrainingMaxes()).mergedWith(updates);

    await _db.collection('users').doc(uid).set({
      'trainingMaxes': merged.toJson(),
    }, SetOptions(merge: true));
  }
}
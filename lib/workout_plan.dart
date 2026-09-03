import 'workout_day.dart';
import 'training_maxes.dart';

class WorkoutPlan {
  final String splitType;
  final List<WorkoutDay> days;
  final TrainingMaxes? trainingMaxes;

  WorkoutPlan({required this.splitType, required this.days, this.trainingMaxes});

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    return WorkoutPlan(
      splitType: json['splitType'],
      days: (json['days'] as List)
          .map((d) => WorkoutDay.fromJson(d))
          .toList(),
      trainingMaxes: json['trainingMaxes'] != null
          ? TrainingMaxes.fromJson(json['trainingMaxes'])
          : null,
    );
  }
}
import 'workout_day.dart';

class WorkoutPlan {
  final String splitType;
  final List<WorkoutDay> days;

  WorkoutPlan({required this.splitType, required this.days});

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    return WorkoutPlan(
      splitType: json['splitType'],
      days: (json['days'] as List)
          .map((d) => WorkoutDay.fromJson(d))
          .toList(),
    );
  }
}
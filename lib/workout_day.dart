import 'exercise.dart';

class WorkoutDay {
  final String dayLabel;
  final List<Exercise> exercises;

  WorkoutDay({required this.dayLabel, required this.exercises});

  factory WorkoutDay.fromJson(Map<String, dynamic> json) {
    return WorkoutDay(
      dayLabel: json['dayLabel'],
      exercises: (json['exercises'] as List)
          .map((e) => Exercise.fromJson(e))
          .toList(),
    );
  }
}
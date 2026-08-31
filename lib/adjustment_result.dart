import 'exercise.dart';

class AdjustmentResult {
  final Exercise updatedExercise;
  final String explanation;

  AdjustmentResult({required this.updatedExercise, required this.explanation});

  factory AdjustmentResult.fromJson(Map<String, dynamic> json) {
    return AdjustmentResult(
      updatedExercise: Exercise.fromJson(json['updatedExercise']),
      explanation: json['explanation'],
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:toughlove_app/adjustment_result.dart';

void main() {
  group('AdjustmentResult.fromJson', () {
    test('parses a weighted exercise update', () {
      final json = {
        'updatedExercise': {
          'name': 'Barbell Squat',
          'sets': 4,
          'repsLow': 4,
          'repsHigh': 6,
          'weight': 235.0,
        },
        'explanation': 'Strong set — added 10 lbs for next time.',
      };

      final result = AdjustmentResult.fromJson(json);

      expect(result.updatedExercise.name, 'Barbell Squat');
      expect(result.updatedExercise.weight, 235.0);
      expect(result.updatedExercise.sets, 4);
      expect(result.updatedExercise.repsLow, 4);
      expect(result.updatedExercise.repsHigh, 6);
      expect(result.explanation, 'Strong set — added 10 lbs for next time.');
    });

    test('parses a bodyweight exercise update with zero weight', () {
      final json = {
        'updatedExercise': {
          'name': 'Push-ups',
          'sets': 3,
          'repsLow': 12,
          'repsHigh': 22,
          'weight': 0,
        },
        'explanation': 'That looked easy — bumped your target reps up for next time.',
      };

      final result = AdjustmentResult.fromJson(json);

      expect(result.updatedExercise.weight, 0.0);
      expect(result.updatedExercise.repsLow, 12);
      expect(result.updatedExercise.repsHigh, 22);
    });
  });
}

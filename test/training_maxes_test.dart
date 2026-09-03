import 'package:flutter_test/flutter_test.dart';
import 'package:toughlove_app/training_maxes.dart';

void main() {
  group('TrainingMaxes.fromJson / toJson', () {
    test('round-trips all three lifts', () {
      final json = {'squat': 270.0, 'bench': 180.0, 'deadlift': 315.0};

      final maxes = TrainingMaxes.fromJson(json);

      expect(maxes.squat, 270.0);
      expect(maxes.bench, 180.0);
      expect(maxes.deadlift, 315.0);
      expect(maxes.toJson(), json);
    });

    test('handles partial data with missing lifts as null', () {
      final maxes = TrainingMaxes.fromJson({'squat': 270.0});

      expect(maxes.squat, 270.0);
      expect(maxes.bench, isNull);
      expect(maxes.deadlift, isNull);
    });

    test('parses integer JSON values as doubles', () {
      // Firestore/JSON can hand back whole numbers as ints, not doubles.
      final maxes = TrainingMaxes.fromJson({'squat': 270, 'bench': 180, 'deadlift': 315});

      expect(maxes.squat, 270.0);
      expect(maxes.bench, 180.0);
      expect(maxes.deadlift, 315.0);
    });
  });

  group('TrainingMaxes.isEmpty', () {
    test('is true when every lift is null', () {
      expect(const TrainingMaxes().isEmpty, isTrue);
    });

    test('is false when at least one lift is set', () {
      expect(const TrainingMaxes(squat: 270.0).isEmpty, isFalse);
    });
  });

  group('TrainingMaxes.mergedWith', () {
    test('overlays only the non-null updates onto the base', () {
      const base = TrainingMaxes(squat: 270.0, bench: 180.0, deadlift: 315.0);
      const updates = TrainingMaxes(squat: 280.0);

      final merged = base.mergedWith(updates);

      expect(merged.squat, 280.0); // updated
      expect(merged.bench, 180.0); // unchanged, preserved from base
      expect(merged.deadlift, 315.0); // unchanged, preserved from base
    });

    test('fills in previously-unset lifts from a base with nulls', () {
      const base = TrainingMaxes(squat: 270.0);
      const updates = TrainingMaxes(bench: 160.0);

      final merged = base.mergedWith(updates);

      expect(merged.squat, 270.0);
      expect(merged.bench, 160.0);
      expect(merged.deadlift, isNull);
    });
  });
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toughlove_app/tracked_lift_series.dart';

void main() {
  group('extractTrackedLiftSeries', () {
    test('extracts and sorts a tracked lift oldest-to-newest', () {
      final logs = [
        {
          'loggedAt': Timestamp.fromDate(DateTime(2026, 9, 3)),
          'exercises': [
            {'name': 'Barbell Squat', 'weight': 245.0},
          ],
        },
        {
          'loggedAt': Timestamp.fromDate(DateTime(2026, 8, 27)),
          'exercises': [
            {'name': 'Barbell Squat', 'weight': 235.0},
          ],
        },
      ];

      final series = extractTrackedLiftSeries(logs);

      expect(series['Barbell Squat'], hasLength(2));
      expect(series['Barbell Squat']![0].date, DateTime(2026, 8, 27));
      expect(series['Barbell Squat']![0].weight, 235.0);
      expect(series['Barbell Squat']![1].date, DateTime(2026, 9, 3));
      expect(series['Barbell Squat']![1].weight, 245.0);
    });

    test('ignores non-tracked exercises', () {
      final logs = [
        {
          'loggedAt': Timestamp.fromDate(DateTime(2026, 9, 3)),
          'exercises': [
            {'name': 'Cable Chest Fly', 'weight': 20.0},
          ],
        },
      ];

      final series = extractTrackedLiftSeries(logs);

      expect(series, isEmpty);
    });

    test('omits lifts with no logged entries entirely', () {
      final logs = [
        {
          'loggedAt': Timestamp.fromDate(DateTime(2026, 9, 3)),
          'exercises': [
            {'name': 'Deadlift', 'weight': 315.0},
          ],
        },
      ];

      final series = extractTrackedLiftSeries(logs);

      expect(series.keys, ['Deadlift']);
      expect(series.containsKey('Barbell Squat'), isFalse);
    });

    test('returns empty map for no logs', () {
      expect(extractTrackedLiftSeries([]), isEmpty);
    });

    test('collapses multiple same-day logs of the same lift into one point, keeping the latest', () {
      final logs = [
        {
          'loggedAt': Timestamp.fromDate(DateTime(2026, 9, 3, 9, 0)),
          'exercises': [
            {'name': 'Barbell Squat', 'weight': 245.0},
          ],
        },
        {
          'loggedAt': Timestamp.fromDate(DateTime(2026, 9, 3, 17, 0)),
          'exercises': [
            {'name': 'Barbell Squat', 'weight': 250.0},
          ],
        },
      ];

      final series = extractTrackedLiftSeries(logs);

      expect(series['Barbell Squat'], hasLength(1));
      expect(series['Barbell Squat']![0].weight, 250.0); // the later log that day wins
    });

    test('keeps separate points for the same lift on different days', () {
      final logs = [
        {
          'loggedAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
          'exercises': [
            {'name': 'Deadlift', 'weight': 300.0},
          ],
        },
        {
          'loggedAt': Timestamp.fromDate(DateTime(2026, 9, 3)),
          'exercises': [
            {'name': 'Deadlift', 'weight': 310.0},
          ],
        },
      ];

      final series = extractTrackedLiftSeries(logs);

      expect(series['Deadlift'], hasLength(2));
    });
  });
}

import 'package:cloud_firestore/cloud_firestore.dart';

const trackedLiftNames = [
  'Barbell Squat',
  'Barbell Bench Press',
  'Deadlift',
];

class WeightPoint {
  final DateTime date;
  final double weight;

  WeightPoint(this.date, this.weight);
}

/// Extracts a (date, weight) series per tracked lift from raw log documents,
/// sorted oldest-to-newest for charting. Lifts with no logged entries are
/// omitted from the result entirely.
Map<String, List<WeightPoint>> extractTrackedLiftSeries(List<Map<String, dynamic>> logs) {
  final series = <String, List<WeightPoint>>{};

  for (final log in logs) {
    final loggedAt = log['loggedAt'];
    if (loggedAt is! Timestamp) continue;
    final date = loggedAt.toDate();

    final exercises = log['exercises'] as List? ?? [];
    for (final ex in exercises) {
      final name = ex['name'] as String?;
      if (name == null || !trackedLiftNames.contains(name)) continue;

      final weight = ex['weight'];
      if (weight is! num) continue;

      series.putIfAbsent(name, () => []).add(WeightPoint(date, weight.toDouble()));
    }
  }

  for (final points in series.values) {
    points.sort((a, b) => a.date.compareTo(b.date));
  }

  return series;
}

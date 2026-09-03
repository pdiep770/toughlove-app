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
/// omitted from the result entirely. At most one point per calendar day per
/// lift -- if a lift was logged more than once on the same day, the latest
/// entry that day wins. Without this, days with more than one log produce
/// extra x-axis ticks that land on the same calendar date, rendering as a
/// visibly repeated date label.
Map<String, List<WeightPoint>> extractTrackedLiftSeries(List<Map<String, dynamic>> logs) {
  final byLiftAndDay = <String, Map<DateTime, WeightPoint>>{};

  for (final log in logs) {
    final loggedAt = log['loggedAt'];
    if (loggedAt is! Timestamp) continue;
    final date = loggedAt.toDate();
    final day = DateTime(date.year, date.month, date.day);

    final exercises = log['exercises'] as List? ?? [];
    for (final ex in exercises) {
      final name = ex['name'] as String?;
      if (name == null || !trackedLiftNames.contains(name)) continue;

      final weight = ex['weight'];
      if (weight is! num) continue;

      final pointsByDay = byLiftAndDay.putIfAbsent(name, () => {});
      final existing = pointsByDay[day];
      if (existing == null || date.isAfter(existing.date)) {
        pointsByDay[day] = WeightPoint(date, weight.toDouble());
      }
    }
  }

  return byLiftAndDay.map((name, pointsByDay) {
    final points = pointsByDay.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    return MapEntry(name, points);
  });
}

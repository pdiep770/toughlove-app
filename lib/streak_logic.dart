// Pure streak date-math, kept separate from streak_service.dart's Firestore
// code so it's unit-testable without any mocking -- same pattern as
// tracked_lift_series.dart.

String dateKey(DateTime d) {
  final month = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$month-$day';
}

/// A streak between two people stays alive if either logs a workout or sends
/// a chat message on a given day. Both actions call this with the *same*
/// day-key, so touching twice in one day (e.g. a workout log and a message)
/// must not double-count -- that's the lastStreakDate == today branch below.
int computeNextStreak(int currentStreak, String? lastStreakDate, String today, String yesterday) {
  if (lastStreakDate == today) {
    return currentStreak; // already touched today, no-op
  } else if (lastStreakDate == yesterday) {
    return currentStreak + 1;
  } else {
    return 1; // gap of 2+ days, or no prior streak at all
  }
}

/// A streak's stored count can go stale (nobody touched it in 2+ days) without
/// anything actively resetting it in Firestore -- reads must treat it as dead
/// rather than displaying a leftover positive number.
bool isStreakAlive(String? lastStreakDate, String today, String yesterday) {
  return lastStreakDate == today || lastStreakDate == yesterday;
}

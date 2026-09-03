import 'package:flutter_test/flutter_test.dart';
import 'package:toughlove_app/streak_logic.dart';

void main() {
  group('dateKey', () {
    test('formats as YYYY-MM-DD with zero-padding', () {
      expect(dateKey(DateTime(2026, 9, 3)), '2026-09-03');
      expect(dateKey(DateTime(2026, 1, 1)), '2026-01-01');
      expect(dateKey(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('ignores the time-of-day component', () {
      expect(dateKey(DateTime(2026, 9, 3, 23, 59)), '2026-09-03');
    });
  });

  group('computeNextStreak', () {
    const today = '2026-09-03';
    const yesterday = '2026-09-02';

    test('touching again the same day does not increment', () {
      expect(computeNextStreak(5, today, today, yesterday), 5);
    });

    test('touching on a consecutive day increments by one', () {
      expect(computeNextStreak(5, yesterday, today, yesterday), 6);
    });

    test('a gap of two or more days resets to one', () {
      expect(computeNextStreak(5, '2026-08-20', today, yesterday), 1);
    });

    test('no prior streak at all starts at one', () {
      expect(computeNextStreak(0, null, today, yesterday), 1);
    });
  });

  group('isStreakAlive', () {
    const today = '2026-09-03';
    const yesterday = '2026-09-02';

    test('alive when last touched today', () {
      expect(isStreakAlive(today, today, yesterday), isTrue);
    });

    test('alive when last touched yesterday', () {
      expect(isStreakAlive(yesterday, today, yesterday), isTrue);
    });

    test('dead when last touched two or more days ago', () {
      expect(isStreakAlive('2026-08-20', today, yesterday), isFalse);
    });

    test('dead when never touched', () {
      expect(isStreakAlive(null, today, yesterday), isFalse);
    });
  });
}

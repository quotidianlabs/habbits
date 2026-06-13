import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/dates.dart';
import 'package:habbits/domain/streak.dart';

void main() {
  final today = DateTime(2026, 6, 13);
  Set<DateTime> daysBack(List<int> offsets) =>
      offsets.map((o) => DateTime(2026, 6, 13 - o)).toSet();

  final cases = <String, ({Set<DateTime> completed, int expected})>{
    'empty set is 0': (completed: <DateTime>{}, expected: 0),
    'only today is 1': (completed: daysBack([0]), expected: 1),
    'today + yesterday is 2': (completed: daysBack([0, 1]), expected: 2),
    'yesterday only (today unchecked) keeps streak alive at 1':
        (completed: daysBack([1]), expected: 1),
    'two days ago only (yesterday missing) is 0':
        (completed: daysBack([2]), expected: 0),
    'today + yesterday, gap at 2 days ago is 2':
        (completed: daysBack([0, 1, 3]), expected: 2),
    'ten-day run is 10': (completed: daysBack([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]), expected: 10),
  };

  cases.forEach((name, c) {
    test(name, () {
      expect(currentStreak(c.completed, today), c.expected);
    });
  });

  test('counts correctly across a month boundary', () {
    final march1 = DateTime(2026, 3, 1);
    final completed = {
      DateTime(2026, 3, 1),
      DateTime(2026, 2, 28),
      DateTime(2026, 2, 27),
    };
    expect(currentStreak(completed, march1), 3);
  });

  test('normalizes inputs that carry a time component', () {
    final completed = {DateTime(2026, 6, 13, 9, 0), DateTime(2026, 6, 12, 23, 59)};
    expect(currentStreak(completed, DateTime(2026, 6, 13, 14, 0)), 2);
  });
}

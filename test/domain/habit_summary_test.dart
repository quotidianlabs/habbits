import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/services/database/database.dart';
import 'package:habbits/domain/models/habit_summary.dart';
import 'package:habbits/domain/models/habit_with_dates.dart';

HabitWithDates _row(Set<DateTime> dates) => HabitWithDates(
  Habit(
    id: 1,
    name: 'Read',
    color: 0xFF00897B,
    reminderTime: null,
    sortOrder: 0,
    createdAt: DateTime(2026, 1, 1),
  ),
  dates,
);

void main() {
  final today = DateTime(2026, 6, 13);

  test('composes streak, doneToday, percent, and dates', () {
    final summary = HabitSummary.from(
      _row({DateTime(2026, 6, 13), DateTime(2026, 6, 12)}),
      today,
    );
    expect(summary.streak, 2);
    expect(summary.doneToday, isTrue);
    expect(summary.completionPercent, 100);
    expect(summary.dates, {DateTime(2026, 6, 13), DateTime(2026, 6, 12)});
  });

  test('empty completions: streak 0, not done, percent null', () {
    final summary = HabitSummary.from(_row({}), today);
    expect(summary.streak, 0);
    expect(summary.doneToday, isFalse);
    expect(summary.completionPercent, isNull);
    expect(summary.dates, isEmpty);
  });

  test('normalizes time-carrying inputs and a non-normalized today', () {
    final summary = HabitSummary.from(
      _row({DateTime(2026, 6, 13, 9, 0), DateTime(2026, 6, 12, 23, 59)}),
      DateTime(2026, 6, 13, 14, 30),
    );
    expect(summary.doneToday, isTrue, reason: 'today matches despite the clock time');
    expect(
      summary.dates,
      {DateTime(2026, 6, 13), DateTime(2026, 6, 12)},
      reason: 'stored dates are day-only',
    );
  });
}

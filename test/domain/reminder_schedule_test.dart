import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/reminder_schedule.dart';

void main() {
  // now = Saturday 2026-06-14, 10:00 local.
  final now = DateTime(2026, 6, 14, 10, 0);

  ReminderHabit habit(int id, String time, {bool done = false}) =>
      ReminderHabit(id: id, name: 'H$id', time: time, doneToday: done);

  test('no enabled habits -> empty schedule', () {
    expect(computeReminderSchedule(const [], now), isEmpty);
  });

  test('one habit, not done, time later today -> today + 13 future days', () {
    final s = computeReminderSchedule([habit(1, '20:00')], now);
    expect(s.length, 14); // maxBuffer
    expect(s.first.habitId, 1);
    expect(s.first.when, DateTime(2026, 6, 14, 20, 0)); // today 20:00
    expect(s.last.when, DateTime(2026, 6, 27, 20, 0)); // +13 days
  });

  test('today is skipped when the habit is already done today', () {
    final s = computeReminderSchedule([habit(1, '20:00', done: true)], now);
    expect(s.length, 13);
    expect(s.first.when, DateTime(2026, 6, 15, 20, 0)); // starts tomorrow
  });

  test("today is skipped when its time has already passed", () {
    // 08:00 is before now (10:00).
    final s = computeReminderSchedule([habit(1, '08:00')], now);
    expect(s.length, 13);
    expect(s.first.when, DateTime(2026, 6, 15, 8, 0));
  });

  test('iOS budget splits days across habits and total stays <= 64', () {
    final habits = [for (var i = 1; i <= 8; i++) habit(i, '20:00')];
    final s = computeReminderSchedule(habits, now);
    expect(s.length, 64); // 8 habits * (64/8 = 8) days
    final perHabit = <int, int>{};
    for (final r in s) {
      perHabit[r.habitId] = (perHabit[r.habitId] ?? 0) + 1;
    }
    expect(perHabit.values.every((c) => c == 8), isTrue);
  });

  test('carries the habit name and times across days', () {
    final s = computeReminderSchedule([habit(7, '07:30')], now);
    expect(s.every((r) => r.habitName == 'H7'), isTrue);
    expect(s.every((r) => r.when.hour == 7 && r.when.minute == 30), isTrue);
  });
}

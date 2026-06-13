import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/heatmap.dart';

void main() {
  // 2026-06-13 is a Saturday; its week's Monday is 2026-06-08.
  final today = DateTime(2026, 6, 13);

  test('single-week grid classifies each cell', () {
    // Created Wednesday 2026-06-10; completed Thursday 2026-06-11.
    final data = buildHeatmap(
      completed: {DateTime(2026, 6, 11)},
      createdAt: DateTime(2026, 6, 10),
      today: today,
    );
    expect(data.weeks.length, 1);
    final week = data.weeks.single; // Mon..Sun = Jun 8..14
    expect(week[0].state, CellState.beforeCreation); // Mon Jun 8
    expect(week[1].state, CellState.beforeCreation); // Tue Jun 9
    expect(week[2].state, CellState.notCompleted);   // Wed Jun 10 (created)
    expect(week[3].state, CellState.completed);       // Thu Jun 11 (done)
    expect(week[4].state, CellState.notCompleted);   // Fri Jun 12
    expect(week[5].state, CellState.notCompleted);   // Sat Jun 13 (today)
    expect(week[6].state, CellState.future);          // Sun Jun 14
  });

  test('rows are Monday..Sunday and dates line up', () {
    final data = buildHeatmap(
      completed: const {},
      createdAt: DateTime(2026, 6, 8),
      today: today,
    );
    final week = data.weeks.single;
    expect(week[0].date, DateTime(2026, 6, 8)); // Monday
    expect(week[6].date, DateTime(2026, 6, 14)); // Sunday
  });

  test('full history spans from the creation week to today week', () {
    // Created 2026-05-25 (a Monday) -> 3 week-columns through 2026-06-08 week.
    final data = buildHeatmap(
      completed: const {},
      createdAt: DateTime(2026, 5, 25),
      today: today,
    );
    expect(data.weeks.length, 3);
  });

  test('maxWeeks keeps only the most recent N week-columns', () {
    final data = buildHeatmap(
      completed: const {},
      createdAt: DateTime(2026, 5, 25), // would be 3 weeks
      today: today,
      maxWeeks: 2,
    );
    expect(data.weeks.length, 2);
    // The kept columns are the most recent ones; last column is today's week.
    expect(data.weeks.last[5].date, DateTime(2026, 6, 13));
  });
}

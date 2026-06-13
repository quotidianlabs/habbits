import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/heatmap.dart';

void main() {
  // 2026-06-13 is a Saturday; its week's Monday is 2026-06-08.
  final today = DateTime(2026, 6, 13);

  test('one-week window classifies past, today, and future cells', () {
    final data = buildHeatmap(
      completed: {DateTime(2026, 6, 11)},
      today: today,
      weeks: 1,
    );
    expect(data.weeks.length, 1);
    final week = data.weeks.single; // Mon..Sun = Jun 8..14
    expect(week[0].state, CellState.notCompleted); // Mon Jun 8 (past, editable)
    expect(week[2].state, CellState.notCompleted); // Wed Jun 10
    expect(week[3].state, CellState.completed);     // Thu Jun 11 (done)
    expect(week[5].state, CellState.notCompleted); // Sat Jun 13 (today)
    expect(week[6].state, CellState.future);        // Sun Jun 14
  });

  test('rows are Monday..Sunday and dates line up', () {
    final data = buildHeatmap(completed: const {}, today: today, weeks: 1);
    final week = data.weeks.single;
    expect(week[0].date, DateTime(2026, 6, 8));
    expect(week[6].date, DateTime(2026, 6, 14));
  });

  test('weeks controls how many week-columns are returned (most recent N)', () {
    final data = buildHeatmap(completed: const {}, today: today, weeks: 3);
    expect(data.weeks.length, 3);
    expect(data.weeks.last[5].date, DateTime(2026, 6, 13)); // today in last column
  });

  test('default window is 6 weeks', () {
    final data = buildHeatmap(completed: const {}, today: today);
    expect(data.weeks.length, 6);
  });

  test('past days are editable regardless of any creation date (no beforeCreation)', () {
    // A day weeks in the past is notCompleted (tappable), never blank/non-editable.
    final data = buildHeatmap(completed: const {}, today: today, weeks: 4);
    expect(data.weeks.first.first.state, CellState.notCompleted);
  });
}

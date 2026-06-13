import 'dates.dart';

/// Classification of one heatmap cell.
enum CellState { completed, notCompleted, future }

class HeatmapCell {
  const HeatmapCell(this.date, this.state);
  final DateTime date;
  final CellState state;
}

/// A heatmap: a list of week-columns, each a list of exactly 7 cells ordered
/// Monday..Sunday.
class HeatmapData {
  const HeatmapData(this.weeks);
  final List<List<HeatmapCell>> weeks;
}

/// Builds the most recent [weeks] week-columns ending at the week containing
/// [today] (Monday..Sunday rows). Every non-future day is editable — there is no
/// creation-date restriction, so any past day in the window can be backfilled.
/// Future days (after [today]) are blank and never tappable.
HeatmapData buildHeatmap({
  required Set<DateTime> completed,
  required DateTime today,
  int weeks = 6,
}) {
  final days = completed.map(dateOnly).toSet();
  final t = dateOnly(today);

  final lastMonday = mondayOf(t);
  final firstMonday = DateTime(
      lastMonday.year, lastMonday.month, lastMonday.day - 7 * (weeks - 1));

  final result = <List<HeatmapCell>>[];
  var weekStart = firstMonday;
  while (!weekStart.isAfter(lastMonday)) {
    final week = <HeatmapCell>[];
    for (var i = 0; i < 7; i++) {
      final date = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
      final CellState state;
      if (date.isAfter(t)) {
        state = CellState.future;
      } else if (days.contains(date)) {
        state = CellState.completed;
      } else {
        state = CellState.notCompleted;
      }
      week.add(HeatmapCell(date, state));
    }
    result.add(week);
    weekStart = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
  }
  return HeatmapData(result);
}

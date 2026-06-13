import 'dates.dart';

/// Classification of one heatmap cell.
enum CellState { completed, notCompleted, future, beforeCreation }

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

/// Builds the grid from [completed] dates, the habit's [createdAt], and [today].
/// When [maxWeeks] is non-null, only the most recent [maxWeeks] week-columns are
/// returned (used by the compact home card); null returns full history from the
/// creation week.
HeatmapData buildHeatmap({
  required Set<DateTime> completed,
  required DateTime createdAt,
  required DateTime today,
  int? maxWeeks,
}) {
  final days = completed.map(dateOnly).toSet();
  final created = dateOnly(createdAt);
  final t = dateOnly(today);

  final lastMonday = mondayOf(t);
  var firstMonday = mondayOf(created);
  if (maxWeeks != null) {
    final byMax = DateTime(
        lastMonday.year, lastMonday.month, lastMonday.day - 7 * (maxWeeks - 1));
    if (byMax.isAfter(firstMonday)) firstMonday = byMax;
  }

  final weeks = <List<HeatmapCell>>[];
  var weekStart = firstMonday;
  while (!weekStart.isAfter(lastMonday)) {
    final week = <HeatmapCell>[];
    for (var i = 0; i < 7; i++) {
      final date =
          DateTime(weekStart.year, weekStart.month, weekStart.day + i);
      final CellState state;
      if (date.isAfter(t)) {
        state = CellState.future;
      } else if (date.isBefore(created)) {
        state = CellState.beforeCreation;
      } else if (days.contains(date)) {
        state = CellState.completed;
      } else {
        state = CellState.notCompleted;
      }
      week.add(HeatmapCell(date, state));
    }
    weeks.add(week);
    weekStart = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
  }
  return HeatmapData(weeks);
}

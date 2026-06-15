import '../../data/services/database/database.dart';

/// View-model value for one habit (home card and detail screen).
class HabitSummary {
  HabitSummary({
    required this.habit,
    required this.streak,
    required this.doneToday,
    required this.completionPercent,
    required this.dates,
  });
  final Habit habit;
  final int streak;
  final bool doneToday;

  /// 30-day completion percentage, or null when there is no window yet ("—").
  final int? completionPercent;

  /// All dates this habit was completed on (for the heatmap).
  final Set<DateTime> dates;
}

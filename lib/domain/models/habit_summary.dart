import '../../data/services/database/database.dart';
import '../completion_stats.dart' as stats;
import '../dates.dart';
import '../streak.dart';
import 'habit_with_dates.dart';

/// View-model value for one habit (home card and detail screen).
class HabitSummary {
  HabitSummary({
    required this.habit,
    required this.streak,
    required this.doneToday,
    required this.completionPercent,
    required this.dates,
  });

  /// Composes a habit's completion dates into its display scalars. The single
  /// home for this derivation; both the home list and the detail screen build
  /// summaries through here.
  factory HabitSummary.from(HabitWithDates row, DateTime today) {
    final day = dateOnly(today);
    final completed = {for (final d in row.dates) dateOnly(d)};
    return HabitSummary(
      habit: row.habit,
      streak: currentStreak(completed, day),
      doneToday: completed.contains(day),
      completionPercent: stats.completionPercent(completed, day),
      dates: completed,
    );
  }
  final Habit habit;
  final int streak;
  final bool doneToday;

  /// 30-day completion percentage, or null when there is no window yet ("—").
  final int? completionPercent;

  /// All dates this habit was completed on (for the heatmap).
  final Set<DateTime> dates;
}

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/database.dart';
import '../data/habit_dao.dart';
import '../domain/completion_stats.dart';
import '../domain/dates.dart';
import '../domain/streak.dart';

part 'habit_providers.g.dart';

/// View-model for one habit (home card and detail screen).
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

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

@riverpod
HabitDao habitDao(Ref ref) => ref.watch(appDatabaseProvider).habitDao;

@riverpod
Stream<List<HabitSummary>> habitSummaries(Ref ref) {
  final dao = ref.watch(habitDaoProvider);
  return dao.watchHabitsWithDates().map((rows) {
    final today = dateOnly(DateTime.now());
    return [
      for (final row in rows)
        HabitSummary(
          habit: row.habit,
          streak: currentStreak(row.dates, today),
          doneToday: row.dates.contains(today),
          completionPercent:
              completionPercent(row.dates, row.habit.createdAt, today),
          dates: row.dates,
        ),
    ];
  });
}

/// A single habit's summary, derived from [habitSummariesProvider]. Returns null
/// while loading or after the habit has been deleted.
@riverpod
HabitSummary? habitDetail(Ref ref, int habitId) {
  final summaries = ref.watch(habitSummariesProvider).value;
  if (summaries == null) return null;
  for (final s in summaries) {
    if (s.habit.id == habitId) return s;
  }
  return null;
}

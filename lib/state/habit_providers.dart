import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/database.dart';
import '../data/habit_dao.dart';
import '../domain/dates.dart';
import '../domain/streak.dart';

part 'habit_providers.g.dart';

/// View-model for one row in the habit list.
class HabitSummary {
  HabitSummary({required this.habit, required this.streak, required this.doneToday});
  final Habit habit;
  final int streak;
  final bool doneToday;
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
        ),
    ];
  });
}

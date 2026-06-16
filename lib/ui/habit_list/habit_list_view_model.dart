import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repositories/habit_repository.dart';
import '../../domain/completion_stats.dart';
import '../../domain/dates.dart';
import '../../domain/models/habit_summary.dart';
import '../../domain/streak.dart';
import '../core/habit_colors.dart';

part 'habit_list_view_model.g.dart';

/// View model for the home list: the summaries stream + check-off / reorder /
/// create commands. Depends only on [HabitRepository].
@riverpod
class HabitListViewModel extends _$HabitListViewModel {
  @override
  Stream<List<HabitSummary>> build() {
    final repo = ref.watch(habitRepositoryProvider);
    return repo.watchHabits().map((rows) {
      final today = dateOnly(DateTime.now());
      return [
        for (final row in rows)
          HabitSummary(
            habit: row.habit,
            streak: currentStreak(row.dates, today),
            doneToday: row.dates.contains(today),
            completionPercent: completionPercent(
              row.dates,
              row.habit.createdAt,
              today,
            ),
            dates: row.dates,
          ),
      ];
    });
  }

  Future<void> toggleToday(int habitId) => ref
      .read(habitRepositoryProvider)
      .toggleCompletion(habitId, dateOnly(DateTime.now()));

  Future<void> reorder(List<int> orderedIds) =>
      ref.read(habitRepositoryProvider).reorderHabits(orderedIds);

  Future<void> createHabit(String name, {int color = kDefaultHabitColor}) =>
      ref.read(habitRepositoryProvider).createHabit(name: name, color: color);
}

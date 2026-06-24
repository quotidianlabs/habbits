import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repositories/habit_repository.dart';
import '../../domain/models/habit_summary.dart';
import '../core/current_day.dart';
import '../core/habit_colors.dart';

part 'habit_list_view_model.g.dart';

/// View model for the home list: the summaries stream + check-off / reorder /
/// create commands. Depends only on [HabitRepository].
@riverpod
class HabitListViewModel extends _$HabitListViewModel {
  @override
  Stream<List<HabitSummary>> build() {
    final repo = ref.watch(habitRepositoryProvider);
    final today = ref.watch(currentDayProvider);
    return repo.watchHabits().map(
      (rows) => [for (final row in rows) HabitSummary.from(row, today)],
    );
  }

  Future<void> toggleToday(int habitId) => ref
      .read(habitRepositoryProvider)
      .toggleCompletion(habitId, ref.read(currentDayProvider));

  Future<void> reorder(List<int> orderedIds) =>
      ref.read(habitRepositoryProvider).reorderHabits(orderedIds);

  Future<void> createHabit(String name, {int color = kDefaultHabitColor}) =>
      ref.read(habitRepositoryProvider).createHabit(name: name, color: color);
}

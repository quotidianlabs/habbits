import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repositories/habit_repository.dart';
import '../../domain/models/habit_summary.dart';
import '../core/current_day.dart';

part 'habit_detail_view_model.g.dart';

/// View model for a single habit's detail screen. Watches its own habit through
/// [HabitRepository] and composes the summary via [HabitSummary.from]; commands
/// go through the repository. Independent of the home list view model.
@riverpod
class HabitDetailViewModel extends _$HabitDetailViewModel {
  @override
  Stream<HabitSummary?> build(int habitId) {
    final repo = ref.watch(habitRepositoryProvider);
    final today = ref.watch(currentDayProvider);
    return repo
        .watchHabit(habitId)
        .map((row) => row == null ? null : HabitSummary.from(row, today));
  }

  Future<void> toggle(DateTime date) =>
      ref.read(habitRepositoryProvider).toggleCompletion(habitId, date);
  Future<void> editHabit(String name, int color) async {
    final repo = ref.read(habitRepositoryProvider);
    await repo.renameHabit(habitId, name);
    await repo.setColor(habitId, color);
  }

  Future<void> delete() =>
      ref.read(habitRepositoryProvider).deleteHabit(habitId);
  Future<void> setReminder(String? hhmm) =>
      ref.read(habitRepositoryProvider).setReminderTime(habitId, hhmm);
}

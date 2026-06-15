import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repositories/habit_repository.dart';
import '../../domain/models/habit_summary.dart';
import '../habit_list/habit_list_view_model.dart';

part 'habit_detail_view_model.g.dart';

/// View model for a single habit's detail screen. State derives from the list
/// view model; commands go through [HabitRepository].
@riverpod
class HabitDetailViewModel extends _$HabitDetailViewModel {
  @override
  HabitSummary? build(int habitId) {
    final summaries = ref.watch(habitListViewModelProvider).value;
    if (summaries == null) return null;
    for (final s in summaries) {
      if (s.habit.id == habitId) return s;
    }
    return null;
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

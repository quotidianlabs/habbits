import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/models/backup_data.dart';
import '../../domain/models/habit_with_dates.dart';
import '../habit_dao.dart';
import '../../state/habit_providers.dart' show habitDaoProvider;

part 'habit_repository.g.dart';

/// The data-layer seam for all habit data. View models depend on this, never on
/// the DAO directly.
class HabitRepository {
  HabitRepository(this._dao);
  final HabitDao _dao;

  Stream<List<HabitWithDates>> watchHabits() => _dao.watchHabitsWithDates();
  Future<List<HabitWithDates>> getHabits() => _dao.getHabitsWithDates();
  Future<int> createHabit({required String name, required int color}) =>
      _dao.createHabit(name: name, color: color);
  Future<void> renameHabit(int id, String name) => _dao.renameHabit(id, name);
  Future<void> deleteHabit(int id) => _dao.deleteHabit(id);
  Future<void> toggleCompletion(int habitId, DateTime date) =>
      _dao.toggleCompletion(habitId, date);
  Future<void> reorderHabits(List<int> orderedIds) =>
      _dao.reorderHabits(orderedIds);
  Future<void> setReminderTime(int id, String? hhmm) =>
      _dao.setReminderTime(id, hhmm);
  Future<void> importReplace(List<BackupHabit> habits) =>
      _dao.importReplace(habits);
}

/// Provides the singleton [HabitRepository] for the app.
@Riverpod(keepAlive: true)
HabitRepository habitRepository(Ref ref) =>
    HabitRepository(ref.watch(habitDaoProvider));

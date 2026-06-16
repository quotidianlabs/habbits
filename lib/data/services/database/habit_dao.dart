import 'package:drift/drift.dart';

import '../../../domain/dates.dart';
import '../../../domain/models/backup_data.dart';
import '../../../domain/models/habit_with_dates.dart';
import 'database.dart';

part 'habit_dao.g.dart';

@DriftAccessor(tables: [Habits, Completions])
class HabitDao extends DatabaseAccessor<AppDatabase> with _$HabitDaoMixin {
  HabitDao(super.db);

  Future<int> createHabit({required String name, required int color}) async {
    final existing = await select(habits).get();
    final nextOrder = existing.isEmpty
        ? 0
        : existing.map((h) => h.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    return into(habits).insert(
      HabitsCompanion.insert(
        name: name,
        color: color,
        sortOrder: nextOrder,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> renameHabit(int id, String name) {
    return (update(
      habits,
    )..where((h) => h.id.equals(id))).write(HabitsCompanion(name: Value(name)));
  }

  Future<void> setColor(int id, int color) {
    return (update(habits)..where((h) => h.id.equals(id))).write(
      HabitsCompanion(color: Value(color)),
    );
  }

  /// Persists a new ordering: sets each habit's sortOrder to its index in
  /// [orderedIds], in a single transaction. Callers must pass every habit's id
  /// exactly once; ids not present in the table are silently skipped, and any
  /// habit omitted from [orderedIds] keeps its old sortOrder.
  Future<void> reorderHabits(List<int> orderedIds) async {
    await transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (update(habits)..where((h) => h.id.equals(orderedIds[i]))).write(
          HabitsCompanion(sortOrder: Value(i)),
        );
      }
    });
  }

  Future<void> setReminderTime(int id, String? hhmm) {
    return (update(habits)..where((h) => h.id.equals(id))).write(
      HabitsCompanion(reminderTime: Value(hhmm)),
    );
  }

  Future<void> deleteHabit(int id) {
    return (delete(habits)..where((h) => h.id.equals(id))).go();
  }

  /// Toggles a completion for [habitId] on [date]: inserts if absent, deletes if
  /// present. Idempotent with respect to the displayed state.
  Future<void> toggleCompletion(int habitId, DateTime date) async {
    final iso = formatIsoDate(date);
    final existing =
        await (select(completions)..where(
              (c) => c.habitId.equals(habitId) & c.localDate.equals(iso),
            ))
            .getSingleOrNull();

    if (existing != null) {
      await (delete(completions)..where((c) => c.id.equals(existing.id))).go();
    } else {
      await into(completions).insert(
        CompletionsCompanion.insert(
          habitId: habitId,
          localDate: iso,
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  /// Groups [rows] from a habits ⋈ completions join into [HabitWithDates]
  /// instances, preserving the order in which habits first appear.
  List<HabitWithDates> _group(List<TypedResult> rows) {
    final byId = <int, HabitWithDates>{};
    final order = <int>[];
    for (final row in rows) {
      final habit = row.readTable(habits);
      if (!byId.containsKey(habit.id)) {
        byId[habit.id] = HabitWithDates(habit, <DateTime>{});
        order.add(habit.id);
      }
      final completion = row.readTableOrNull(completions);
      if (completion != null) {
        byId[habit.id]!.dates.add(parseIsoDate(completion.localDate));
      }
    }
    return [for (final id in order) byId[id]!];
  }

  /// Reactive stream of every habit with its completion dates, ordered by
  /// sortOrder. Emits on any change to either table.
  Stream<List<HabitWithDates>> watchHabitsWithDates() {
    final q = select(habits).join([
      leftOuterJoin(completions, completions.habitId.equalsExp(habits.id)),
    ])..orderBy([OrderingTerm(expression: habits.sortOrder)]);
    return q.watch().map(_group);
  }

  /// One-shot read of every habit with its completion dates.
  Future<List<HabitWithDates>> getHabitsWithDates() async {
    final q = select(habits).join([
      leftOuterJoin(completions, completions.habitId.equalsExp(habits.id)),
    ])..orderBy([OrderingTerm(expression: habits.sortOrder)]);
    return _group(await q.get());
  }

  /// Replaces ALL data with [data] in a single transaction: deletes every
  /// completion and habit, then inserts each habit and its completions.
  /// Completion `created_at` is set to now (audit-only).
  Future<void> importReplace(List<BackupHabit> data) async {
    await transaction(() async {
      await delete(completions).go();
      await delete(habits).go();
      for (final h in data) {
        final id = await into(habits).insert(
          HabitsCompanion.insert(
            name: h.name,
            color: h.color,
            reminderTime: Value(h.reminderTime),
            sortOrder: h.sortOrder,
            createdAt: h.createdAt,
          ),
        );
        for (final iso in h.completions) {
          await into(completions).insert(
            CompletionsCompanion.insert(
              habitId: id,
              localDate: iso,
              createdAt: DateTime.now(),
            ),
          );
        }
      }
    });
  }
}

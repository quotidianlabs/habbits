import 'package:drift/drift.dart';

import '../domain/dates.dart';
import 'database.dart';

part 'habit_dao.g.dart';

/// A habit paired with the set of dates it was completed on.
class HabitWithDates {
  HabitWithDates(this.habit, this.dates);
  final Habit habit;
  final Set<DateTime> dates;
}

@DriftAccessor(tables: [Habits, Completions])
class HabitDao extends DatabaseAccessor<AppDatabase> with _$HabitDaoMixin {
  HabitDao(super.db);

  Future<int> createHabit({required String name, required int color}) async {
    final existing = await select(habits).get();
    return into(habits).insert(HabitsCompanion.insert(
      name: name,
      color: color,
      sortOrder: existing.length,
      createdAt: DateTime.now(),
    ));
  }

  Future<void> renameHabit(int id, String name) {
    return (update(habits)..where((h) => h.id.equals(id)))
        .write(HabitsCompanion(name: Value(name)));
  }

  Future<void> deleteHabit(int id) {
    return (delete(habits)..where((h) => h.id.equals(id))).go();
  }

  /// Toggles a completion for [habitId] on [date]: inserts if absent, deletes if
  /// present. Idempotent with respect to the displayed state.
  Future<void> toggleCompletion(int habitId, DateTime date) async {
    final iso = formatIsoDate(date);
    final existing = await (select(completions)
          ..where((c) => c.habitId.equals(habitId) & c.localDate.equals(iso)))
        .getSingleOrNull();

    if (existing != null) {
      await (delete(completions)..where((c) => c.id.equals(existing.id))).go();
    } else {
      await into(completions).insert(CompletionsCompanion.insert(
        habitId: habitId,
        localDate: iso,
        createdAt: DateTime.now(),
      ));
    }
  }

  /// Reactive stream of every habit with its completion dates, ordered by
  /// sortOrder. Emits on any change to either table.
  Stream<List<HabitWithDates>> watchHabitsWithDates() {
    final query = select(habits).join([
      leftOuterJoin(completions, completions.habitId.equalsExp(habits.id)),
    ])
      ..orderBy([OrderingTerm(expression: habits.sortOrder)]);

    return query.watch().map((rows) {
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
    });
  }
}

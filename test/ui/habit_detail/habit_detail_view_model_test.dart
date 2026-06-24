import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/services/database/database.dart';
import 'package:habbits/data/services/database/database_providers.dart';
import 'package:habbits/domain/dates.dart';
import 'package:habbits/domain/models/habit_summary.dart';
import 'package:habbits/ui/core/current_day.dart';
import 'package:habbits/ui/habit_detail/habit_detail_view_model.dart';

/// A [CurrentDay] pinned to a fixed day, with a setter so a test can advance it
/// past midnight and assert the detail VM recomposes.
class _FixedCurrentDay extends CurrentDay {
  _FixedCurrentDay(this._day);
  final DateTime _day;
  @override
  DateTime build() => _day;
  void setDay(DateTime d) => state = d;
}

/// Completes with the first detail-VM value (a `HabitSummary?`) matching
/// [predicate]. Note: the detail VM is built with NO list view model in the
/// container — it loads its own habit.
Future<HabitSummary?> nextDetail(
  ProviderContainer container,
  int habitId,
  bool Function(HabitSummary?) predicate,
) {
  final completer = Completer<HabitSummary?>();
  ProviderSubscription<AsyncValue<HabitSummary?>>? sub;
  sub = container.listen(habitDetailViewModelProvider(habitId), (_, next) {
    if (next.hasValue && predicate(next.value) && !completer.isCompleted) {
      completer.complete(next.value);
      sub?.close();
    }
  });
  final cur = container.read(habitDetailViewModelProvider(habitId));
  if (cur.hasValue && predicate(cur.value) && !completer.isCompleted) {
    completer.complete(cur.value);
    sub.close();
  }
  return completer.future;
}

void main() {
  final pinnedDay = DateTime(2026, 6, 13);

  ProviderContainer makeContainer(AppDatabase db) => ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      currentDayProvider.overrideWith(() => _FixedCurrentDay(pinnedDay)),
    ],
  );

  test('composes its own habit summary, re-emitting on toggle', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = makeContainer(db);
    addTearDown(container.dispose);
    addTearDown(db.close);

    final id = await container
        .read(habitDaoProvider)
        .createHabit(name: 'Read', color: 1);

    // Toggle on (via the VM command) -> doneToday for the pinned day.
    await container
        .read(habitDetailViewModelProvider(id).notifier)
        .toggle(pinnedDay);
    final on = await nextDetail(container, id, (s) => s?.doneToday ?? false);
    expect(on?.habit.name, 'Read');
    expect(on?.streak, 1);
    expect(on?.dates, {pinnedDay});

    // Toggle off -> re-emits with doneToday false.
    await container
        .read(habitDetailViewModelProvider(id).notifier)
        .toggle(pinnedDay);
    final off = await nextDetail(
      container,
      id,
      (s) => s != null && !s.doneToday,
    );
    expect(off?.dates, isEmpty);
  });

  test('yields null for a missing id', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = makeContainer(db);
    addTearDown(container.dispose);
    addTearDown(db.close);

    expect(await nextDetail(container, 9999, (s) => s == null), isNull);
  });

  test('recomposes when currentDayProvider advances past midnight', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = makeContainer(db);
    addTearDown(container.dispose);
    addTearDown(db.close);

    final id = await container
        .read(habitDaoProvider)
        .createHabit(name: 'Read', color: 1);
    await container.read(habitDaoProvider).toggleCompletion(id, pinnedDay);

    // Done today while today == the completion day.
    expect(
      (await nextDetail(container, id, (s) => s?.doneToday ?? false)),
      isNotNull,
    );

    // Advance "today" one day; the completion is now yesterday.
    (container.read(currentDayProvider.notifier) as _FixedCurrentDay).setDay(
      nextLocalMidnight(pinnedDay),
    );
    final next = await nextDetail(
      container,
      id,
      (s) => s != null && !s.doneToday,
    );
    expect(next?.dates, {pinnedDay}); // same data, recomputed against new today
  });

  test('rename updates the streamed habit', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = makeContainer(db);
    addTearDown(container.dispose);
    addTearDown(db.close);

    final id = await container
        .read(habitDaoProvider)
        .createHabit(name: 'Old', color: 1);
    await nextDetail(container, id, (s) => s?.habit.name == 'Old');

    await container
        .read(habitDetailViewModelProvider(id).notifier)
        .editHabit('New', 0xFF009688);
    final renamed = await nextDetail(
      container,
      id,
      (s) => s?.habit.name == 'New',
    );
    expect(renamed?.habit.color, 0xFF009688);
  });

  test('editHabit updates name and color', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = makeContainer(db);
    addTearDown(container.dispose);
    addTearDown(db.close);

    final id = await container
        .read(habitDaoProvider)
        .createHabit(name: 'Old', color: 0xFF009688);

    await container
        .read(habitDetailViewModelProvider(id).notifier)
        .editHabit('New', 0xFFE53935);
    final rows = await container.read(habitDaoProvider).getHabitsWithDates();
    expect(rows.single.habit.name, 'New');
    expect(rows.single.habit.color, 0xFFE53935);
  });
}

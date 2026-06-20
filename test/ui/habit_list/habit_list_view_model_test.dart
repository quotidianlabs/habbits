import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/services/database/database.dart';
import 'package:habbits/data/services/database/database_providers.dart';
import 'package:habbits/domain/dates.dart';
import 'package:habbits/domain/models/habit_summary.dart';
import 'package:habbits/ui/core/current_day.dart';
import 'package:habbits/ui/habit_list/habit_list_view_model.dart';

/// A [CurrentDay] pinned to a fixed day, bypassing the real timer/lifecycle.
class _FixedCurrentDay extends CurrentDay {
  _FixedCurrentDay(this._day);
  final DateTime _day;
  @override
  DateTime build() => _day;
}

Future<List<HabitSummary>> nextSummaries(
  ProviderContainer container,
  bool Function(List<HabitSummary>) predicate,
) {
  final completer = Completer<List<HabitSummary>>();
  ProviderSubscription<AsyncValue<List<HabitSummary>>>? sub;
  sub = container.listen(habitListViewModelProvider, (_, next) {
    final value = next.value;
    if (value != null && predicate(value) && !completer.isCompleted) {
      completer.complete(value);
      sub?.close();
    }
  });
  final current = container.read(habitListViewModelProvider).value;
  if (current != null && predicate(current) && !completer.isCompleted) {
    completer.complete(current);
    sub.close();
  }
  return completer.future;
}

void main() {
  test('exposes summaries and toggleToday flips today', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    final id = await container
        .read(habitDaoProvider)
        .createHabit(name: 'Read', color: 1);
    await nextSummaries(container, (list) => list.any((s) => s.habit.id == id));

    await container.read(habitListViewModelProvider.notifier).toggleToday(id);
    final list = await nextSummaries(
      container,
      (l) => l.any((s) => s.habit.id == id && s.doneToday),
    );
    expect(list.single.doneToday, isTrue);
  });

  test('createHabit adds a habit to the stream', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    await container
        .read(habitListViewModelProvider.notifier)
        .createHabit('Exercise', color: 0xFF00897B);

    final list = await nextSummaries(
      container,
      (l) => l.any((s) => s.habit.name == 'Exercise'),
    );
    expect(list.single.habit.name, 'Exercise');
  });

  test('reorder rewrites the stream order', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    final a = await container
        .read(habitDaoProvider)
        .createHabit(name: 'A', color: 1);
    final b = await container
        .read(habitDaoProvider)
        .createHabit(name: 'B', color: 1);
    await nextSummaries(container, (l) => l.length == 2);

    await container.read(habitListViewModelProvider.notifier).reorder([b, a]);
    final list = await nextSummaries(
      container,
      (l) => l.length == 2 && l.first.habit.id == b,
    );
    expect(list.map((s) => s.habit.name), ['B', 'A']);
  });

  test('anchors today on currentDayProvider, not wall-clock now', () async {
    final completionDay = dateOnly(DateTime.now());
    final nextDay = nextLocalMidnight(completionDay);

    Future<bool> doneTodayWith(DateTime overrideDay) async {
      final db = AppDatabase(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentDayProvider.overrideWith(() => _FixedCurrentDay(overrideDay)),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(db.close);

      final id = await container
          .read(habitDaoProvider)
          .createHabit(name: 'Read', color: 1);
      await container
          .read(habitDaoProvider)
          .toggleCompletion(id, completionDay);
      final summaries = await nextSummaries(
        container,
        (l) =>
            l.any((s) => s.habit.id == id && s.dates.contains(completionDay)),
      );
      return summaries.single.doneToday;
    }

    // Same day as the completion -> done today; the day after -> not done today.
    expect(await doneTodayWith(completionDay), isTrue);
    expect(await doneTodayWith(nextDay), isFalse);
  });

  test('computes streak, doneToday, percent, and dates', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    final id = await container
        .read(habitDaoProvider)
        .createHabit(name: 'Read', color: 1);
    final today = dateOnly(DateTime.now());
    await container.read(habitDaoProvider).toggleCompletion(id, today);

    final summaries = await nextSummaries(
      container,
      (l) => l.any((s) => s.habit.id == id && s.doneToday),
    );
    final s = summaries.single;
    expect(s.habit.name, 'Read');
    expect(s.streak, 1);
    expect(s.doneToday, isTrue);
    expect(s.completionPercent, 100); // created today, checked today
    expect(s.dates, {today});
  });
}

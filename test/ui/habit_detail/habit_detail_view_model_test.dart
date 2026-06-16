import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/services/database/database.dart';
import 'package:habbits/data/services/database/database_providers.dart';
import 'package:habbits/domain/models/habit_summary.dart';
import 'package:habbits/ui/habit_detail/habit_detail_view_model.dart';
import 'package:habbits/ui/habit_list/habit_list_view_model.dart';

Future<void> nextWhere(
  ProviderContainer container,
  bool Function(List<HabitSummary>) predicate,
) {
  final completer = Completer<void>();
  ProviderSubscription<AsyncValue<List<HabitSummary>>>? sub;
  sub = container.listen(habitListViewModelProvider, (_, next) {
    final v = next.value;
    if (v != null && predicate(v) && !completer.isCompleted) {
      completer.complete();
      sub?.close();
    }
  });
  final cur = container.read(habitListViewModelProvider).value;
  if (cur != null && predicate(cur) && !completer.isCompleted) {
    completer.complete();
    sub.close();
  }
  return completer.future;
}

void main() {
  test('exposes the habit and rename updates it', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    final id = await container
        .read(habitDaoProvider)
        .createHabit(name: 'Old', color: 1);
    // keep list stream alive for the derived detail VM
    final keep = container.listen(habitListViewModelProvider, (_, next) {});
    addTearDown(keep.close);
    await nextWhere(container, (l) => l.any((s) => s.habit.id == id));

    expect(container.read(habitDetailViewModelProvider(id))?.habit.name, 'Old');

    await container
        .read(habitDetailViewModelProvider(id).notifier)
        .editHabit('New', 0xFF009688);
    await nextWhere(
      container,
      (l) => l.any((s) => s.habit.id == id && s.habit.name == 'New'),
    );
    expect(container.read(habitDetailViewModelProvider(id))?.habit.name, 'New');
  });

  test('editHabit updates name and color', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    final id = await container
        .read(habitDaoProvider)
        .createHabit(name: 'Old', color: 0xFF009688);
    final keep = container.listen(habitListViewModelProvider, (_, _) {});
    addTearDown(keep.close);
    await nextWhere(container, (l) => l.any((s) => s.habit.id == id));

    await container
        .read(habitDetailViewModelProvider(id).notifier)
        .editHabit('New', 0xFFE53935);
    final rows = await container.read(habitDaoProvider).getHabitsWithDates();
    expect(rows.single.habit.name, 'New');
    expect(rows.single.habit.color, 0xFFE53935);
  });

  test('returns the matching summary and null for a missing id', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    final id = await container
        .read(habitDaoProvider)
        .createHabit(name: 'Walk', color: 1);
    final keep = container.listen(habitListViewModelProvider, (_, _) {});
    addTearDown(keep.close);
    await nextWhere(container, (l) => l.any((s) => s.habit.id == id));

    expect(
      container.read(habitDetailViewModelProvider(id))?.habit.name,
      'Walk',
    );
    expect(container.read(habitDetailViewModelProvider(9999)), isNull);
  });
}

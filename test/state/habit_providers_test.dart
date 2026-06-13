import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/database.dart';
import 'package:habbits/domain/dates.dart';
import 'package:habbits/state/habit_providers.dart';

/// Returns the next emission from [habitSummariesProvider] matching [predicate].
Future<List<HabitSummary>> nextSummaries(
  ProviderContainer container,
  bool Function(List<HabitSummary>) predicate,
) {
  final completer = Completer<List<HabitSummary>>();
  ProviderSubscription<AsyncValue<List<HabitSummary>>>? sub;
  sub = container.listen(habitSummariesProvider, (_, next) {
    final value = next.value;
    if (value != null && predicate(value) && !completer.isCompleted) {
      completer.complete(value);
      sub?.close();
    }
  });
  // Check current value immediately.
  final current = container.read(habitSummariesProvider).value;
  if (current != null && predicate(current) && !completer.isCompleted) {
    completer.complete(current);
    sub.close();
  }
  return completer.future;
}

void main() {
  test('habitSummaries computes streak, doneToday, percent, and dates', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    final id = await container.read(habitDaoProvider).createHabit(name: 'Read', color: 1);
    final today = dateOnly(DateTime.now());
    await container.read(habitDaoProvider).toggleCompletion(id, today);

    // Wait for an emission where the habit is checked today.
    final summaries = await nextSummaries(
      container,
      (list) => list.any((s) => s.habit.id == id && s.doneToday),
    );

    final s = summaries.single;
    expect(s.habit.name, 'Read');
    expect(s.streak, 1);
    expect(s.doneToday, isTrue);
    expect(s.completionPercent, 100); // created today, checked today
    expect(s.dates, {today});
  });

  test('habitDetail returns the matching habit summary', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    final id = await container.read(habitDaoProvider).createHabit(name: 'Walk', color: 1);

    // Wait for the stream to include the newly created habit.
    await nextSummaries(
      container,
      (list) => list.any((s) => s.habit.id == id),
    );

    // Keep the source stream alive so the derived provider has data.
    final sub = container.listen(habitSummariesProvider, (_, _) {});
    addTearDown(sub.close);

    final detail = container.read(habitDetailProvider(id));
    expect(detail, isNotNull);
    expect(detail!.habit.name, 'Walk');

    final missing = container.read(habitDetailProvider(9999));
    expect(missing, isNull);
  });
}

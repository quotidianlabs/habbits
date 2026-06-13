import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/database.dart';
import 'package:habbits/domain/dates.dart';
import 'package:habbits/state/habit_providers.dart';

void main() {
  test('habitSummaries computes streak and doneToday for today check-off', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    final id = await container.read(habitDaoProvider).createHabit(name: 'Read', color: 1);
    await container.read(habitDaoProvider).toggleCompletion(id, dateOnly(DateTime.now()));

    // Keep a subscription alive so the auto-dispose provider isn't torn down
    // before the stream emits its first value.
    final sub = container.listen(habitSummariesProvider, (prev, next) {});
    final summaries = await container.read(habitSummariesProvider.future);
    sub.close();
    expect(summaries.single.habit.name, 'Read');
    expect(summaries.single.streak, 1);
    expect(summaries.single.doneToday, isTrue);
  });
}

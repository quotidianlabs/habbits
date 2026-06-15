import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/database.dart';
import 'package:habbits/data/repositories/habit_repository.dart';
import 'package:habbits/domain/models/backup_data.dart';

void main() {
  late AppDatabase db;
  late HabitRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = HabitRepository(db.habitDao);
  });
  tearDown(() => db.close());

  test('create then watch returns the habit with its dates', () async {
    final id = await repo.createHabit(name: 'Read', color: 1);
    await repo.toggleCompletion(id, DateTime(2026, 6, 14));
    final rows = await repo.watchHabits().first;
    expect(rows.single.habit.name, 'Read');
    expect(rows.single.dates, {DateTime(2026, 6, 14)});
  });

  test('reorder rewrites order; delete removes', () async {
    final a = await repo.createHabit(name: 'A', color: 1);
    final b = await repo.createHabit(name: 'B', color: 1);
    await repo.reorderHabits([b, a]);
    var rows = await repo.getHabits();
    expect(rows.map((r) => r.habit.name), ['B', 'A']);
    await repo.deleteHabit(b);
    rows = await repo.getHabits();
    expect(rows.map((r) => r.habit.name), ['A']);
  });

  test('importReplace round-trips backup data', () async {
    await repo.importReplace([
      BackupHabit(
        name: 'Run',
        color: 2,
        reminderTime: '07:00',
        sortOrder: 0,
        createdAt: DateTime(2026, 1, 1),
        completions: const ['2026-06-14'],
      ),
    ]);
    final rows = await repo.getHabits();
    expect(rows.single.habit.name, 'Run');
    expect(rows.single.habit.reminderTime, '07:00');
    expect(rows.single.dates, {DateTime(2026, 6, 14)});
  });
}

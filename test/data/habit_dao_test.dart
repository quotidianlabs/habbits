import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/database.dart';
import 'package:habbits/data/habit_dao.dart';
import 'package:habbits/domain/backup.dart';

void main() {
  late AppDatabase db;
  late HabitDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.habitDao;
  });
  tearDown(() => db.close());

  test('createHabit assigns incrementing sort order', () async {
    final a = await dao.createHabit(name: 'A', color: 1);
    final b = await dao.createHabit(name: 'B', color: 2);
    final rows = await dao.watchHabitsWithDates().first;
    expect(rows.map((r) => r.habit.id), [a, b]);
    expect(rows.map((r) => r.habit.sortOrder), [0, 1]);
  });

  test('renameHabit changes the name', () async {
    final id = await dao.createHabit(name: 'Old', color: 1);
    await dao.renameHabit(id, 'New');
    final rows = await dao.watchHabitsWithDates().first;
    expect(rows.single.habit.name, 'New');
  });

  test('toggleCompletion is idempotent: on then off nets to empty', () async {
    final id = await dao.createHabit(name: 'Read', color: 1);
    final date = DateTime(2026, 6, 13);

    await dao.toggleCompletion(id, date);
    var rows = await dao.watchHabitsWithDates().first;
    expect(rows.single.dates, {DateTime(2026, 6, 13)});

    await dao.toggleCompletion(id, date);
    rows = await dao.watchHabitsWithDates().first;
    expect(rows.single.dates, isEmpty);
  });

  test('watchHabitsWithDates groups completion dates per habit', () async {
    final id = await dao.createHabit(name: 'Meditate', color: 1);
    await dao.toggleCompletion(id, DateTime(2026, 6, 13));
    await dao.toggleCompletion(id, DateTime(2026, 6, 12));

    final rows = await dao.watchHabitsWithDates().first;
    expect(rows.single.dates, {DateTime(2026, 6, 13), DateTime(2026, 6, 12)});
  });

  test('deleteHabit removes the habit and its completions', () async {
    final id = await dao.createHabit(name: 'Gone', color: 1);
    await dao.toggleCompletion(id, DateTime(2026, 6, 13));

    await dao.deleteHabit(id);

    final rows = await dao.watchHabitsWithDates().first;
    expect(rows, isEmpty);
    final completions = await db.select(db.completions).get();
    expect(completions, isEmpty);
  });

  test('getHabitsWithDates returns all habits with their dates (one-shot)', () async {
    final id = await dao.createHabit(name: 'Read', color: 1);
    await dao.toggleCompletion(id, DateTime(2026, 6, 13));
    await dao.toggleCompletion(id, DateTime(2026, 6, 12));

    final rows = await dao.getHabitsWithDates();
    expect(rows.single.habit.name, 'Read');
    expect(rows.single.dates, {DateTime(2026, 6, 13), DateTime(2026, 6, 12)});
  });

  test('importReplace wipes existing data and loads the new set', () async {
    final old = await dao.createHabit(name: 'Old', color: 1);
    await dao.toggleCompletion(old, DateTime(2026, 6, 1));

    await dao.importReplace([
      BackupHabit(
        name: 'Medicine',
        color: 0xFF009688,
        reminderTime: '08:30',
        sortOrder: 0,
        createdAt: DateTime(2026, 6, 5),
        completions: const ['2026-06-10', '2026-06-11'],
      ),
    ]);

    final rows = await dao.getHabitsWithDates();
    expect(rows, hasLength(1));
    expect(rows.single.habit.name, 'Medicine');
    expect(rows.single.habit.reminderTime, '08:30');
    expect(rows.single.dates, {DateTime(2026, 6, 10), DateTime(2026, 6, 11)});
  });

  test('importReplace with an empty list clears everything', () async {
    await dao.createHabit(name: 'Gone', color: 1);
    await dao.importReplace(const []);
    expect(await dao.getHabitsWithDates(), isEmpty);
  });
}

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/services/database/database.dart';
import 'package:habbits/data/services/database/habit_dao.dart';
import 'package:habbits/domain/models/backup_data.dart';

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

  test(
    'toggleCompletion tolerates concurrent double-toggle without throwing',
    () async {
      final id = await dao.createHabit(name: 'Read', color: 1);
      final date = DateTime(2026, 6, 20);

      // Two near-simultaneous taps on the same day must not collide on the
      // {habitId, localDate} unique key. Two toggles net to empty; the key
      // invariant is that neither throws a UNIQUE-constraint SqliteException.
      await Future.wait([
        dao.toggleCompletion(id, date),
        dao.toggleCompletion(id, date),
      ]);

      final rows = await dao.watchHabitsWithDates().first;
      expect(rows.single.dates, isEmpty);
    },
  );

  test('watchHabitsWithDates groups completion dates per habit', () async {
    final id = await dao.createHabit(name: 'Meditate', color: 1);
    await dao.toggleCompletion(id, DateTime(2026, 6, 13));
    await dao.toggleCompletion(id, DateTime(2026, 6, 12));

    final rows = await dao.watchHabitsWithDates().first;
    expect(rows.single.dates, {DateTime(2026, 6, 13), DateTime(2026, 6, 12)});
  });

  test('watchHabitWithDates streams one habit, its dates, then null', () async {
    final id = await dao.createHabit(name: 'Read', color: 1);

    // Just the habit, no completions yet.
    var row = await dao.watchHabitWithDates(id).first;
    expect(row?.habit.name, 'Read');
    expect(row?.dates, isEmpty);

    // Re-emits with the date after a toggle.
    await dao.toggleCompletion(id, DateTime(2026, 6, 13));
    row = await dao.watchHabitWithDates(id).first;
    expect(row?.dates, {DateTime(2026, 6, 13)});

    // Null after the habit is deleted.
    await dao.deleteHabit(id);
    expect(await dao.watchHabitWithDates(id).first, isNull);
  });

  test('watchHabitWithDates emits null for an absent id', () async {
    expect(await dao.watchHabitWithDates(9999).first, isNull);
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

  test(
    'getHabitsWithDates returns all habits with their dates (one-shot)',
    () async {
      final id = await dao.createHabit(name: 'Read', color: 1);
      await dao.toggleCompletion(id, DateTime(2026, 6, 13));
      await dao.toggleCompletion(id, DateTime(2026, 6, 12));

      final rows = await dao.getHabitsWithDates();
      expect(rows.single.habit.name, 'Read');
      expect(rows.single.dates, {DateTime(2026, 6, 13), DateTime(2026, 6, 12)});
    },
  );

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

  test('setReminderTime sets and clears a habit reminder', () async {
    final id = await dao.createHabit(name: 'Read', color: 1);

    await dao.setReminderTime(id, '08:30');
    var rows = await dao.getHabitsWithDates();
    expect(rows.single.habit.reminderTime, '08:30');

    await dao.setReminderTime(id, null);
    rows = await dao.getHabitsWithDates();
    expect(rows.single.habit.reminderTime, isNull);
  });

  test('reorderHabits rewrites sortOrder to the new order', () async {
    final a = await dao.createHabit(name: 'A', color: 1);
    final b = await dao.createHabit(name: 'B', color: 1);
    final c = await dao.createHabit(name: 'C', color: 1);

    await dao.reorderHabits([c, a, b]);

    final rows = await dao.getHabitsWithDates();
    expect(rows.map((r) => r.habit.name), ['C', 'A', 'B']);
    expect(rows.map((r) => r.habit.sortOrder), [0, 1, 2]);
  });

  test(
    'createHabit gives a unique trailing sortOrder after a delete',
    () async {
      await dao.createHabit(name: 'A', color: 1); // sortOrder 0
      final b = await dao.createHabit(name: 'B', color: 1); // 1
      await dao.createHabit(name: 'C', color: 1); // 2

      await dao.deleteHabit(b);
      final d = await dao.createHabit(
        name: 'D',
        color: 1,
      ); // must NOT collide with C(2)

      final rows = await dao.getHabitsWithDates();
      expect(rows.map((r) => r.habit.name), ['A', 'C', 'D']);
      final dRow = rows.firstWhere((r) => r.habit.id == d);
      expect(dRow.habit.sortOrder, 3); // max(0,2)+1
      // sort orders are all distinct
      final orders = rows.map((r) => r.habit.sortOrder).toList();
      expect(orders.toSet().length, orders.length);
    },
  );

  test('setColor updates only the color', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db.habitDao.createHabit(name: 'Read', color: 0xFF009688);
    await db.habitDao.setColor(id, 0xFFE53935);
    final rows = await db.habitDao.getHabitsWithDates();
    expect(rows.single.habit.color, 0xFFE53935);
    expect(rows.single.habit.name, 'Read');
  });
}

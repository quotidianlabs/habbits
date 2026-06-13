import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('inserts and reads a habit', () async {
    final id = await db.into(db.habits).insert(HabitsCompanion.insert(
          name: 'Medicine',
          color: 0xFF009688,
          sortOrder: 0,
          createdAt: DateTime(2026, 6, 13),
        ));
    final row = await (db.select(db.habits)..where((h) => h.id.equals(id))).getSingle();
    expect(row.name, 'Medicine');
  });

  test('rejects a duplicate (habitId, localDate)', () async {
    final habitId = await db.into(db.habits).insert(HabitsCompanion.insert(
          name: 'Read', color: 1, sortOrder: 0, createdAt: DateTime(2026, 6, 13)));
    await db.into(db.completions).insert(CompletionsCompanion.insert(
          habitId: habitId, localDate: '2026-06-13', createdAt: DateTime(2026, 6, 13)));

    expect(
      () => db.into(db.completions).insert(CompletionsCompanion.insert(
            habitId: habitId, localDate: '2026-06-13', createdAt: DateTime(2026, 6, 13))),
      throwsA(isA<Exception>()),
    );
  });

  test('deleting a habit cascades to its completions', () async {
    final habitId = await db.into(db.habits).insert(HabitsCompanion.insert(
          name: 'Workout', color: 1, sortOrder: 0, createdAt: DateTime(2026, 6, 13)));
    await db.into(db.completions).insert(CompletionsCompanion.insert(
          habitId: habitId, localDate: '2026-06-13', createdAt: DateTime(2026, 6, 13)));

    await (db.delete(db.habits)..where((h) => h.id.equals(habitId))).go();

    final remaining = await db.select(db.completions).get();
    expect(remaining, isEmpty);
  });
}

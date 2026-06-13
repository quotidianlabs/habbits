import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'habit_dao.dart';

part 'database.g.dart';

class Habits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get color => integer()();
  TextColumn get reminderTime => text().nullable()(); // 'HH:mm', null = none
  IntColumn get sortOrder => integer()();
  DateTimeColumn get createdAt => dateTime()();
}

class Completions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get habitId =>
      integer().references(Habits, #id, onDelete: KeyAction.cascade)();
  TextColumn get localDate => text()(); // 'YYYY-MM-DD'
  DateTimeColumn get createdAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {habitId, localDate},
      ];
}

@DriftDatabase(tables: [Habits, Completions], daos: [HabitDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'habbits'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

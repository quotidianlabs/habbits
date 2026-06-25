import 'package:drift/drift.dart';

import 'connection.dart';
import 'habit_dao.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Habits, Completions], daos: [HabitDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(
        executor != null
            // When an explicit executor is provided (typically in tests),
            // enable synchronous stream closing so that Flutter's fake-async
            // environment doesn't see a pending 0-duration timer after the
            // last stream listener detaches on widget disposal.
            ? DatabaseConnection(executor, closeStreamsSynchronously: true)
            : openConnection(),
      );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

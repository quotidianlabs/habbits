// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_dao.dart';

// ignore_for_file: type=lint
mixin _$HabitDaoMixin on DatabaseAccessor<AppDatabase> {
  $HabitsTable get habits => attachedDatabase.habits;
  $CompletionsTable get completions => attachedDatabase.completions;
  HabitDaoManager get managers => HabitDaoManager(this);
}

class HabitDaoManager {
  final _$HabitDaoMixin _db;
  HabitDaoManager(this._db);
  $$HabitsTableTableManager get habits =>
      $$HabitsTableTableManager(_db.attachedDatabase, _db.habits);
  $$CompletionsTableTableManager get completions =>
      $$CompletionsTableTableManager(_db.attachedDatabase, _db.completions);
}

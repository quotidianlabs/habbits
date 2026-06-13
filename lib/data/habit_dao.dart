import 'package:drift/drift.dart';

import 'database.dart';

part 'habit_dao.g.dart';

@DriftAccessor(tables: [Habits, Completions])
class HabitDao extends DatabaseAccessor<AppDatabase> with _$HabitDaoMixin {
  HabitDao(super.db);
}

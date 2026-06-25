import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/services/database/database.dart';

void main() {
  test('schema creates the habits and completions tables', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // Forcing a query opens the connection and runs migration.onCreate,
    // which builds every table from its column definitions.
    final habits = await db.select(db.habits).get();
    final completions = await db.select(db.completions).get();

    expect(habits, isEmpty);
    expect(completions, isEmpty);
    // The generated table metadata reflects the hand-written column getters.
    expect(db.habits.actualTableName, 'habits');
    expect(db.completions.actualTableName, 'completions');
  });
}

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/services/database/database.dart';
import 'package:habbits/domain/backup_codec.dart';

void main() {
  test('buildBackup snapshots habits with sorted completion dates', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final dao = db.habitDao;
    final id = await dao.createHabit(name: 'Read', color: 7);
    await dao.toggleCompletion(id, DateTime(2026, 6, 12));
    await dao.toggleCompletion(id, DateTime(2026, 6, 10));

    final data = buildBackup(await dao.getHabitsWithDates(),
        DateTime.parse('2026-06-14T09:00:00.000'));

    expect(data.version, 1);
    expect(data.habits.single.name, 'Read');
    expect(data.habits.single.color, 7);
    expect(data.habits.single.completions, ['2026-06-10', '2026-06-12']); // sorted
  });

  test('full round-trip: export -> encode -> decode -> import reproduces data',
      () async {
    final src = AppDatabase(NativeDatabase.memory());
    addTearDown(src.close);
    final a = await src.habitDao.createHabit(name: 'Medicine', color: 0xFF009688);
    await src.habitDao.toggleCompletion(a, DateTime(2026, 6, 10));
    await src.habitDao.toggleCompletion(a, DateTime(2026, 6, 11));
    final b = await src.habitDao.createHabit(name: 'Read', color: 0xFF3366CC);
    await src.habitDao.toggleCompletion(b, DateTime(2026, 6, 9));

    final json = encodeBackup(
        buildBackup(await src.habitDao.getHabitsWithDates(),
            DateTime.parse('2026-06-14T09:00:00.000')));

    final dst = AppDatabase(NativeDatabase.memory());
    addTearDown(dst.close);
    await dst.habitDao.importReplace(decodeBackup(json).habits);

    final rows = await dst.habitDao.getHabitsWithDates();
    expect(rows.map((r) => r.habit.name), ['Medicine', 'Read']);
    expect(rows.map((r) => r.habit.color), [0xFF009688, 0xFF3366CC]);
    expect(rows[0].dates, {DateTime(2026, 6, 10), DateTime(2026, 6, 11)});
    expect(rows[1].dates, {DateTime(2026, 6, 9)});
  });
}

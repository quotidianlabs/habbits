import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/database.dart';
import 'package:habbits/domain/backup.dart';
import 'package:habbits/state/habit_providers.dart';
import 'package:habbits/ui/settings/settings_screen.dart';

void main() {
  testWidgets('renders Export and Import rows', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: SettingsScreen()),
    ));
    expect(find.byKey(const Key('export-data')), findsOneWidget);
    expect(find.byKey(const Key('import-data')), findsOneWidget);
  });

  testWidgets('confirming an import replaces the data', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.habitDao.createHabit(name: 'Old', color: 1);

    final data = BackupData(
      version: 1,
      exportedAt: DateTime(2026, 6, 14),
      habits: [
        BackupHabit(
          name: 'Imported',
          color: 2,
          reminderTime: null,
          sortOrder: 0,
          createdAt: DateTime(2026, 6, 1),
          completions: const ['2026-06-02'],
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: Consumer(builder: (context, ref, _) {
          return ElevatedButton(
            key: const Key('go'),
            onPressed: () => confirmAndImport(context, ref, data),
            child: const Text('go'),
          );
        }),
      ),
    ));

    await tester.tap(find.byKey(const Key('go')));
    await tester.pumpAndSettle();
    expect(find.textContaining('replace'), findsOneWidget); // confirm dialog copy
    await tester.tap(find.byKey(const Key('confirm-import')));
    await tester.pumpAndSettle();

    final rows = await db.habitDao.getHabitsWithDates();
    expect(rows.single.habit.name, 'Imported');
    expect(rows.single.dates, {DateTime(2026, 6, 2)});
  });
}

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/database.dart';
import 'package:habbits/state/habit_providers.dart';
import 'package:habbits/ui/habit_list/habit_list_screen.dart';

Widget _app(AppDatabase db) => ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: HabitListScreen()),
    );

void main() {
  testWidgets('adding a habit shows it in the list', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-habit-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('habit-name-field')), 'Medicine');
    await tester.tap(find.byKey(const Key('habit-name-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Medicine'), findsOneWidget);
    expect(find.text('Streak: 0'), findsOneWidget);
  });

  testWidgets('checking off today bumps the streak to 1', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.habitDao.createHabit(name: 'Read', color: 0xFF009688);
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('checkoff-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Streak: 1'), findsOneWidget);
  });

  testWidgets('deleting a habit requires confirmation then removes it', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.habitDao.createHabit(name: 'Workout', color: 0xFF009688);
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('habit-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.textContaining('permanent'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();

    expect(find.text('Workout'), findsNothing);
  });
}

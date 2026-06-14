import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/database.dart';
import 'package:habbits/state/habit_providers.dart';
import 'package:habbits/ui/habit_list/habit_list_screen.dart';
import 'package:habbits/ui/widgets/day_strip.dart';

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
    expect(find.byType(DayStrip), findsOneWidget);
  });

  testWidgets('checking off today bumps the streak to 1', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.habitDao.createHabit(name: 'Read', color: 0xFF009688);
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(find.text('Streak: 1'), findsOneWidget);
  });

  testWidgets('two habits each render with independent check-off controls',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.habitDao.createHabit(name: 'Read', color: 0xFF009688);
    await db.habitDao.createHabit(name: 'Meditate', color: 0xFF673AB7);
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Meditate'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('Streak: 1'), findsOneWidget);
    expect(find.text('Streak: 0'), findsOneWidget);
  });

  testWidgets('tapping a card opens the detail screen', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.habitDao.createHabit(name: 'Workout', color: 0xFF009688);
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    // Tap the habit name (card body), not the checkbox.
    await tester.tap(find.text('Workout'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('habit-detail-screen')), findsOneWidget);
  });

  testWidgets('home is a reorderable list with a drag handle per habit',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.habitDao.createHabit(name: 'Read', color: 0xFF009688);
    await db.habitDao.createHabit(name: 'Meditate', color: 0xFF673AB7);
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
  });
}

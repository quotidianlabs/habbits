import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/database.dart';
import 'package:habbits/domain/dates.dart';
import 'package:habbits/state/habit_providers.dart';
import 'package:habbits/ui/habit_detail/habit_detail_screen.dart';
import 'package:habbits/ui/widgets/heatmap_grid.dart';

void main() {
  // Insert a habit created 10 days ago so there are past in-range cells to tap.
  Future<int> seedHabit(AppDatabase db) {
    final created = dateOnly(DateTime.now()).subtract(const Duration(days: 10));
    return db.into(db.habits).insert(HabitsCompanion.insert(
          name: 'Medicine',
          color: 0xFF009688,
          sortOrder: 0,
          createdAt: created,
        ));
  }

  Widget app(AppDatabase db, int id) => ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: HabitDetailScreen(habitId: id)),
      );

  testWidgets('renders name, streak, percent, and the heatmap', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await seedHabit(db);

    await tester.pumpWidget(app(db, id));
    await tester.pumpAndSettle();

    expect(find.text('Medicine'), findsOneWidget);
    expect(find.textContaining('Streak'), findsOneWidget);
    expect(find.byKey(const Key('habit-detail-screen')), findsOneWidget);
    expect(find.textContaining('30-day'), findsOneWidget);
    expect(find.byType(HeatmapGrid), findsOneWidget);
  });

  testWidgets('tapping a past in-range cell records a completion (retroactive)',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await seedHabit(db);

    await tester.pumpWidget(app(db, id));
    await tester.pumpAndSettle();

    final target = dateOnly(DateTime.now()).subtract(const Duration(days: 3));
    final iso = formatIsoDate(target);
    await tester.tap(find.byKey(Key('heatmap-cell-$iso')));
    await tester.pumpAndSettle();

    final rows = await (db.select(db.completions)
          ..where((c) => c.localDate.equals(iso)))
        .get();
    expect(rows, hasLength(1));
  });

  testWidgets('renaming updates the title', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await seedHabit(db);

    await tester.pumpWidget(app(db, id));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('detail-rename')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('habit-name-field')), 'Vitamins');
    await tester.tap(find.byKey(const Key('habit-name-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Vitamins'), findsOneWidget);
  });

  testWidgets('shows "—" for a brand-new habit with no eligible window',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db.into(db.habits).insert(HabitsCompanion.insert(
          name: 'New',
          color: 0xFF009688,
          sortOrder: 0,
          createdAt: dateOnly(DateTime.now()), // created today, nothing checked
        ));

    await tester.pumpWidget(app(db, id));
    await tester.pumpAndSettle();

    expect(find.text('30-day: —'), findsOneWidget);
  });

  testWidgets('deleting from detail confirms, removes the habit, and pops',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await seedHabit(db);

    await tester.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('open-detail'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HabitDetailScreen(habitId: id),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.byKey(const Key('open-detail')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('habit-detail-screen')), findsOneWidget);

    await tester.tap(find.byKey(const Key('detail-delete')));
    await tester.pumpAndSettle();
    expect(find.textContaining('permanent'), findsOneWidget); // confirm dialog
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();

    // Popped back to the host; detail screen gone; habit removed from the DB.
    expect(find.byKey(const Key('habit-detail-screen')), findsNothing);
    final habits = await db.select(db.habits).get();
    expect(habits, isEmpty);
  });
}

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/database.dart';
import 'package:habbits/domain/dates.dart';
import 'package:habbits/state/habit_providers.dart';
import 'package:habbits/ui/habit_detail/habit_detail_screen.dart';

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
}

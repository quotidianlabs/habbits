import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/services/database/database.dart';
import 'package:habbits/data/services/database/database_providers.dart';
import 'package:habbits/domain/dates.dart';
import 'package:habbits/l10n/app_localizations.dart';
import 'package:habbits/ui/core/current_day.dart';
import 'package:habbits/ui/habit_detail/habit_detail_screen.dart';
import 'package:habbits/ui/widgets/heatmap_grid.dart';

/// A [CurrentDay] pinned to a fixed day, bypassing the real timer/lifecycle.
class _FixedCurrentDay extends CurrentDay {
  _FixedCurrentDay(this._day);
  final DateTime _day;
  @override
  DateTime build() => _day;
}

void main() {
  // Insert a habit created 10 days ago so there are past in-range cells to tap.
  Future<int> seedHabit(AppDatabase db) {
    final created = dateOnly(DateTime.now()).subtract(const Duration(days: 10));
    return db
        .into(db.habits)
        .insert(
          HabitsCompanion.insert(
            name: 'Medicine',
            color: 0xFF009688,
            sortOrder: 0,
            createdAt: created,
          ),
        );
  }

  Widget app(AppDatabase db, int id, {Locale? locale}) => ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: HabitDetailScreen(habitId: id),
    ),
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

  testWidgets('tapping a day row records a completion (retroactive)', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await seedHabit(db);

    await tester.pumpWidget(app(db, id));
    await tester.pumpAndSettle();

    final target = dateOnly(DateTime.now()).subtract(const Duration(days: 3));
    final iso = formatIsoDate(target);
    await tester.tap(find.byKey(Key('daylist-$iso')));
    await tester.pumpAndSettle();

    final rows = await (db.select(
      db.completions,
    )..where((c) => c.localDate.equals(iso))).get();
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
    await tester.enterText(
      find.byKey(const Key('habit-name-field')),
      'Vitamins',
    );
    await tester.tap(find.byKey(const Key('habit-name-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Vitamins'), findsOneWidget);
  });

  testWidgets('shows "—" for a brand-new habit with no eligible window', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db
        .into(db.habits)
        .insert(
          HabitsCompanion.insert(
            name: 'New',
            color: 0xFF009688,
            sortOrder: 0,
            createdAt: dateOnly(
              DateTime.now(),
            ), // created today, nothing checked
          ),
        );

    await tester.pumpWidget(app(db, id));
    await tester.pumpAndSettle();

    expect(find.text('30-day: —'), findsOneWidget);
  });

  testWidgets(
    'reminder row shows Off and switch off for a habit with no reminder',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await seedHabit(db);

      await tester.pumpWidget(app(db, id));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reminder-row')), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);
      final sw = tester.widget<Switch>(
        find.byKey(const Key('reminder-switch')),
      );
      expect(sw.value, isFalse);
    },
  );

  testWidgets('reminder row shows the time and switch on when set', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await seedHabit(db);
    await db.habitDao.setReminderTime(id, '08:30');

    await tester.pumpWidget(app(db, id));
    await tester.pumpAndSettle();

    final sw = tester.widget<Switch>(find.byKey(const Key('reminder-switch')));
    expect(sw.value, isTrue);
    expect(find.text('8:30 AM'), findsOneWidget);
  });

  testWidgets('toggling the switch off clears the reminder', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await seedHabit(db);
    await db.habitDao.setReminderTime(id, '08:30');

    await tester.pumpWidget(app(db, id));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reminder-switch')));
    await tester.pumpAndSettle();

    final rows = await db.habitDao.getHabitsWithDates();
    expect(rows.single.habit.reminderTime, isNull);
  });

  testWidgets('deleting from detail confirms, removes the habit, and pops', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await seedHabit(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
      ),
    );

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

  testWidgets(
    'recent-days + heatmap follow currentDayProvider, not the clock',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await seedHabit(db);

      // A day far outside the real "now" 30-day window: it only renders as the
      // newest recent-days row if the screen derives today from the provider.
      final pinnedDay = DateTime(2030, 1, 1);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentDayProvider.overrideWith(() => _FixedCurrentDay(pinnedDay)),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HabitDetailScreen(habitId: id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(Key('daylist-${formatIsoDate(pinnedDay)}')),
        findsOneWidget,
      );
    },
  );

  testWidgets('detail shows Russian labels under ru locale', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db.habitDao.createHabit(name: 'Читать', color: 1);
    await tester.pumpWidget(app(db, id, locale: const Locale('ru')));
    await tester.pumpAndSettle();
    expect(find.text('Напоминание'), findsOneWidget);
  });
}

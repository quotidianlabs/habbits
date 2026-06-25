import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/repositories/settings_repository.dart';
import 'package:habbits/data/services/database/database.dart';
import 'package:habbits/data/services/database/database_providers.dart';
import 'package:habbits/domain/models/habit_summary.dart';
import 'package:habbits/l10n/app_localizations.dart';
import 'package:habbits/ui/habit_list/habit_list_screen.dart';
import 'package:habbits/ui/habit_list/habit_list_view_model.dart';
import 'package:habbits/ui/widgets/day_strip.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fake [HabitListViewModel] whose [build] immediately throws, forcing the
/// provider into [AsyncError] and exercising the `error:` branch of the screen.
class _ErrorHabitListViewModel extends HabitListViewModel {
  @override
  Stream<List<HabitSummary>> build() => throw Exception('boom');
}

Widget _app(AppDatabase db, {Locale? locale}) => ProviderScope(
  overrides: [appDatabaseProvider.overrideWithValue(db)],
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const HabitListScreen(),
  ),
);

Widget _appWithPrefs(AppDatabase db, SharedPreferences prefs) => ProviderScope(
  overrides: [
    appDatabaseProvider.overrideWithValue(db),
    sharedPreferencesProvider.overrideWithValue(prefs),
  ],
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: HabitListScreen(),
  ),
);

void main() {
  testWidgets('adding a habit shows it in the list', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-habit-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('habit-name-field')),
      'Medicine',
    );
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

  testWidgets('two habits each render with independent check-off controls', (
    tester,
  ) async {
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

  testWidgets('home is a reorderable list with a drag handle per habit', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.habitDao.createHabit(name: 'Read', color: 0xFF009688);
    await db.habitDao.createHabit(name: 'Meditate', color: 0xFF673AB7);
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
  });

  testWidgets('renders Russian copy when locale is ru', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(_app(db, locale: const Locale('ru')));
    await tester.pumpAndSettle();
    expect(
      find.text('Пока нет привычек. Нажмите +, чтобы добавить.'),
      findsOneWidget,
    );
  });

  testWidgets('renders Russian streak label', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.habitDao.createHabit(name: 'Бег', color: 0xFF009688);
    await tester.pumpWidget(_app(db, locale: const Locale('ru')));
    await tester.pumpAndSettle();
    expect(find.text('Серия: 0'), findsOneWidget);
  });

  testWidgets('tapping settings pushes the settings screen', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_appWithPrefs(db, prefs));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('export-data')), findsOneWidget);
  });

  testWidgets('reordering habits persists the new order', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final a = await db.habitDao.createHabit(name: 'A', color: 1);
    final b = await db.habitDao.createHabit(name: 'B', color: 2);
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    // onReorderItem semantics: newIndex is the target position after removal.
    // Moving A (index 0) to end with 2 items: oldIndex=0, newIndex=1 → [B, A].
    list.onReorderItem!(0, 1);
    await tester.pumpAndSettle();

    final order = (await db.habitDao.getHabitsWithDates())
        .map((h) => h.habit.id)
        .toList();
    expect(order, [b, a]);
  });

  testWidgets('provider error shows the home-error message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          habitListViewModelProvider.overrideWith(_ErrorHabitListViewModel.new),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HabitListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Error: Exception: boom'), findsOneWidget);
  });
}

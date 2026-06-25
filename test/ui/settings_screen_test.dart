import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/repositories/backup_repository.dart';
import 'package:habbits/data/repositories/habit_repository.dart';
import 'package:habbits/data/services/database/database.dart';
import 'package:habbits/data/services/database/database_providers.dart';
import 'package:habbits/data/repositories/settings_repository.dart';
import 'package:habbits/domain/models/backup_data.dart';
import 'package:habbits/domain/models/habit_with_dates.dart';
import 'package:habbits/domain/reminder_schedule.dart';
import 'package:habbits/l10n/app_localizations.dart';
import 'package:habbits/ui/core/locale_controller.dart';
import 'package:habbits/ui/core/notification_permission.dart';
import 'package:habbits/ui/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

/// A [NotificationPermission] pinned to a fixed value for tests.
class _FixedPermission extends NotificationPermission {
  _FixedPermission(this._value);
  final bool? _value;
  @override
  bool? build() => _value;
}

class _FakeBackup extends BackupRepository {
  _FakeBackup(
    super.habits, {
    this.exportThrows = false,
    this.picked,
    this.pickThrows,
  });
  final bool exportThrows;
  final BackupData? picked;
  final Object? pickThrows;
  bool exported = false;

  @override
  Future<void> exportAndShare({required String subject}) async {
    if (exportThrows) throw Exception('share failed');
    exported = true;
  }

  @override
  Future<BackupData?> pickAndDecode() async {
    if (pickThrows != null) throw pickThrows!;
    return picked;
  }
}

Widget settingsAppWithBackup(
  AppDatabase db,
  SharedPreferences prefs,
  BackupRepository backup,
) => ProviderScope(
  overrides: [
    appDatabaseProvider.overrideWithValue(db),
    sharedPreferencesProvider.overrideWithValue(prefs),
    backupRepositoryProvider.overrideWithValue(backup),
  ],
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: SettingsScreen(),
  ),
);

class _ThrowingHabitRepository extends HabitRepository {
  _ThrowingHabitRepository(super.dao);

  @override
  Future<void> importReplace(List<BackupHabit> habits) =>
      throw Exception('db error');

  @override
  Future<List<HabitWithDates>> getHabits() async => [];
}

Widget settingsAppWithBackupAndHabitRepo(
  AppDatabase db,
  SharedPreferences prefs,
  BackupRepository backup,
  HabitRepository habitRepo,
) => ProviderScope(
  overrides: [
    appDatabaseProvider.overrideWithValue(db),
    sharedPreferencesProvider.overrideWithValue(prefs),
    backupRepositoryProvider.overrideWithValue(backup),
    habitRepositoryProvider.overrideWithValue(habitRepo),
  ],
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: SettingsScreen(),
  ),
);

void main() {
  testWidgets('renders Export and Import rows', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final prefs = await _prefs();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    expect(find.byKey(const Key('export-data')), findsOneWidget);
    expect(find.byKey(const Key('import-data')), findsOneWidget);
  });

  Future<void> seedReminderHabits(AppDatabase db, int n) async {
    for (var i = 0; i < n; i++) {
      final id = await db.habitDao.createHabit(name: 'H$i', color: 1);
      await db.habitDao.setReminderTime(id, '20:00');
    }
  }

  Widget settingsApp(AppDatabase db, SharedPreferences prefs) => ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SettingsScreen(),
    ),
  );

  testWidgets('warns when reminder habits exceed the notification budget', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedReminderHabits(db, kIosNotificationBudget + 1);
    final prefs = await _prefs();

    await tester.pumpWidget(settingsApp(db, prefs));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reminder-budget-warning')), findsOneWidget);
  });

  testWidgets('no warning when reminders are within the budget', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedReminderHabits(db, 3);
    final prefs = await _prefs();

    await tester.pumpWidget(settingsApp(db, prefs));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reminder-budget-warning')), findsNothing);
  });

  Widget settingsAppWithPermission(
    AppDatabase db,
    SharedPreferences prefs,
    bool? granted,
  ) => ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationPermissionProvider.overrideWith(
        () => _FixedPermission(granted),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SettingsScreen(),
    ),
  );

  testWidgets('warns when reminders are on but permission is denied', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedReminderHabits(db, 1);
    final prefs = await _prefs();

    await tester.pumpWidget(settingsAppWithPermission(db, prefs, false));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notifications-off-warning')), findsOneWidget);
  });

  testWidgets('no permission warning when granted', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedReminderHabits(db, 1);
    final prefs = await _prefs();

    await tester.pumpWidget(settingsAppWithPermission(db, prefs, true));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notifications-off-warning')), findsNothing);
  });

  testWidgets('no permission warning when there are no reminders', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.habitDao.createHabit(name: 'NoReminder', color: 1);
    final prefs = await _prefs();

    await tester.pumpWidget(settingsAppWithPermission(db, prefs, false));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notifications-off-warning')), findsNothing);
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

    final prefs = await _prefs();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                return ElevatedButton(
                  key: const Key('go'),
                  onPressed: () => confirmAndImport(context, ref, data),
                  child: const Text('go'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('go')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('replace'),
      findsOneWidget,
    ); // confirm dialog copy
    await tester.tap(find.byKey(const Key('confirm-import')));
    await tester.pumpAndSettle();

    final rows = await db.habitDao.getHabitsWithDates();
    expect(rows.single.habit.name, 'Imported');
    expect(rows.single.dates, {DateTime(2026, 6, 2)});
  });

  testWidgets('shows Russian settings title under ru locale', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final prefs = await _prefs();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          locale: Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Настройки'), findsOneWidget);
    expect(find.text('Язык'), findsOneWidget);
  });

  testWidgets('language picker switches app to Russian', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final prefs = await _prefs();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final loc = ref.watch(localeControllerProvider);
            return MaterialApp(
              locale: loc.locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const SettingsScreen(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-tile')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('lang-option-system')),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('lang-option-ru')));
    await tester.pumpAndSettle();
    expect(prefs.getString('locale'), 'ru');
    expect(find.text('Настройки'), findsOneWidget);
  });

  testWidgets('theme picker switches to dark and persists', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('theme-tile')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('theme-option-system')),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('theme-option-dark')));
    await tester.pumpAndSettle();
    expect(prefs.getString('theme'), 'dark');
  });

  testWidgets('tapping Export delegates to the backup repository', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final backup = _FakeBackup(HabitRepository(db.habitDao));
    await tester.pumpWidget(settingsAppWithBackup(db, await _prefs(), backup));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('export-data')));
    await tester.pumpAndSettle();

    expect(backup.exported, isTrue);
  });

  testWidgets('export failure shows the error SnackBar', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final backup = _FakeBackup(
      HabitRepository(db.habitDao),
      exportThrows: true,
    );
    await tester.pumpWidget(settingsAppWithBackup(db, await _prefs(), backup));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('export-data')));
    await tester.pumpAndSettle();

    expect(find.text('Export failed.'), findsOneWidget);
  });

  testWidgets('import of a malformed file shows invalid-backup SnackBar', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final backup = _FakeBackup(
      HabitRepository(db.habitDao),
      pickThrows: const BackupFormatException('bad'),
    );
    await tester.pumpWidget(settingsAppWithBackup(db, await _prefs(), backup));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('import-data')));
    await tester.pumpAndSettle();

    expect(
      find.text("That file isn't a valid Habbits backup."),
      findsOneWidget,
    );
  });

  testWidgets('import read error shows couldnt-read SnackBar', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final backup = _FakeBackup(
      HabitRepository(db.habitDao),
      pickThrows: Exception('io'),
    );
    await tester.pumpWidget(settingsAppWithBackup(db, await _prefs(), backup));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('import-data')));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't read that file."), findsOneWidget);
  });

  testWidgets('import success confirms then applies, showing imported count', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final data = BackupData(
      version: 1,
      exportedAt: DateTime(2026, 6, 14),
      habits: [
        BackupHabit(
          name: 'Read',
          color: 1,
          reminderTime: null,
          sortOrder: 0,
          createdAt: DateTime(2026, 6, 1),
          completions: const [],
        ),
      ],
    );
    final backup = _FakeBackup(HabitRepository(db.habitDao), picked: data);
    await tester.pumpWidget(settingsAppWithBackup(db, await _prefs(), backup));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('import-data')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-import')));
    await tester.pumpAndSettle();

    expect((await db.habitDao.getHabitsWithDates()).single.habit.name, 'Read');
    expect(find.text('Imported 1 habit'), findsOneWidget);
  });

  testWidgets('cancelling the import dialog does not apply data', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final data = BackupData(
      version: 1,
      exportedAt: DateTime(2026, 6, 14),
      habits: [
        BackupHabit(
          name: 'Cancelled',
          color: 1,
          reminderTime: null,
          sortOrder: 0,
          createdAt: DateTime(2026, 6, 1),
          completions: const [],
        ),
      ],
    );
    final backup = _FakeBackup(HabitRepository(db.habitDao), picked: data);
    await tester.pumpWidget(settingsAppWithBackup(db, await _prefs(), backup));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('import-data')));
    await tester.pumpAndSettle();
    // Tap cancel — covers the cancel button onPressed
    await tester.tap(find.byType(TextButton).first);
    await tester.pumpAndSettle();

    expect(await db.habitDao.getHabitsWithDates(), isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('applyImport failure shows import-failed SnackBar', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final data = BackupData(
      version: 1,
      exportedAt: DateTime(2026, 6, 14),
      habits: [
        BackupHabit(
          name: 'WillFail',
          color: 1,
          reminderTime: null,
          sortOrder: 0,
          createdAt: DateTime(2026, 6, 1),
          completions: const [],
        ),
      ],
    );
    final backup = _FakeBackup(HabitRepository(db.habitDao), picked: data);
    final throwingHabitRepo = _ThrowingHabitRepository(db.habitDao);
    await tester.pumpWidget(
      settingsAppWithBackupAndHabitRepo(
        db,
        await _prefs(),
        backup,
        throwingHabitRepo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('import-data')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-import')));
    await tester.pumpAndSettle();

    expect(
      find.text('Import failed. Your existing data was not changed.'),
      findsOneWidget,
    );
  });
}

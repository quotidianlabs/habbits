import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/services/database/database.dart';
import 'package:habbits/data/services/database/database_providers.dart';
import 'package:habbits/data/repositories/settings_repository.dart';
import 'package:habbits/domain/models/backup_data.dart';
import 'package:habbits/l10n/app_localizations.dart';
import 'package:habbits/ui/core/locale_controller.dart';
import 'package:habbits/ui/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

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
}

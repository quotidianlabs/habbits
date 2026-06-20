---
status: shipped
date: 2026-06-14
slug: russian-language
spec: russian-language
pr: aff47ab
---

# Russian Language Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Russian as a fully supported app language alongside English, auto-following the device locale with a persisted in-app override.

**Architecture:** Flutter `gen-l10n` (ARB → typed `AppLocalizations`) for all UI strings; a Riverpod `LocaleController` backed by `shared_preferences` drives `MaterialApp.locale`; `intl` `DateFormat` skeletons render locale-aware dates; the reminder notification body is localized in `ReminderCoordinator` and passed into the plugin boundary.

**Tech Stack:** Flutter 3.44 `flutter_localizations` + `intl`, `shared_preferences`, Riverpod codegen, Drift (unchanged).

**Spec:** `docs/superpowers/specs/2026-06-14-russian-language-design.md`

**Conventions:**
- Generated code (`*.g.dart`, generated `app_localizations*.dart`) **is committed** in this repo.
- Toolchain: `export PATH="/opt/homebrew/bin:$PATH"` before any `flutter`/`dart` command.
- Codegen: `dart run build_runner build --delete-conflicting-outputs` after touching `@riverpod` classes.
- Generated localizations imported as `package:habbits/l10n/app_localizations.dart`.
- Access strings via `AppLocalizations.of(context)` (non-nullable; `nullable-getter: false`).

---

## Task 1: i18n infrastructure (deps, config, ARB files, codegen)

**Files:**
- Modify: `pubspec.yaml`
- Create: `l10n.yaml`
- Create: `lib/l10n/app_en.arb`
- Create: `lib/l10n/app_ru.arb`
- Generated (committed): `lib/l10n/app_localizations.dart`, `lib/l10n/app_localizations_en.dart`, `lib/l10n/app_localizations_ru.dart`

- [ ] **Step 1: Add dependencies to `pubspec.yaml`**

Under `dependencies:` add (keep alphabetical where the file is):
```yaml
  flutter_localizations:
    sdk: flutter
  intl: any
  shared_preferences: ^2.3.0
```
In the existing `flutter:` section (the one with `uses-material-design`/assets), add:
```yaml
  generate: true
```
> `intl: any` lets Flutter pin the intl version it ships with `flutter_localizations` (avoids a version-solve conflict).

- [ ] **Step 2: Create `l10n.yaml` at repo root**

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
nullable-getter: false
synthetic-package: false
```

- [ ] **Step 3: Create `lib/l10n/app_en.arb` (template)**

```json
{
  "@@locale": "en",

  "settings": "Settings",

  "exportTitle": "Export data",
  "exportSubtitle": "Save all habits and history to a JSON file",
  "importTitle": "Import data",
  "importSubtitle": "Replace all data from a JSON backup",
  "exportFailed": "Export failed.",
  "couldntReadFile": "Couldn't read that file.",
  "invalidBackupFile": "That file isn't a valid Habbits backup.",

  "replaceTitle": "Replace all data?",
  "replaceBody": "This will replace all current habits and history with the file’s contents ({count, plural, one{{count} habit} other{{count} habits}}). This cannot be undone.",
  "@replaceBody": {
    "placeholders": { "count": { "type": "int" } }
  },
  "cancel": "Cancel",
  "replace": "Replace",
  "importFailed": "Import failed. Your existing data was not changed.",
  "importedHabits": "{count, plural, one{Imported {count} habit} other{Imported {count} habits}}",
  "@importedHabits": {
    "placeholders": { "count": { "type": "int" } }
  },

  "language": "Language",
  "languageSystem": "System default",

  "noHabits": "No habits yet. Tap + to add one.",
  "homeError": "Error: {error}",
  "@homeError": {
    "placeholders": { "error": { "type": "String" } }
  },
  "streakLabel": "Streak: {count}",
  "@streakLabel": {
    "placeholders": { "count": { "type": "int" } }
  },

  "thirtyDayLabel": "30-day: {value}",
  "@thirtyDayLabel": {
    "placeholders": { "value": { "type": "String" } }
  },
  "reminderTitle": "Reminder",
  "reminderOff": "Off",
  "rename": "Rename",
  "delete": "Delete",

  "newHabit": "New habit",
  "renameHabit": "Rename habit",
  "nameLabel": "Name",
  "save": "Save",
  "deleteHabitTitle": "Delete \"{name}\"?",
  "@deleteHabitTitle": {
    "placeholders": { "name": { "type": "String" } }
  },
  "deleteHabitBody": "This permanently deletes the habit and all its check-off history. This cannot be undone.",

  "todayPrefix": "Today · {date}",
  "@todayPrefix": {
    "placeholders": { "date": { "type": "String" } }
  },

  "reminderBody": "Time to check in"
}
```

- [ ] **Step 4: Create `lib/l10n/app_ru.arb`**

```json
{
  "@@locale": "ru",

  "settings": "Настройки",

  "exportTitle": "Экспорт данных",
  "exportSubtitle": "Сохранить все привычки и историю в JSON-файл",
  "importTitle": "Импорт данных",
  "importSubtitle": "Заменить все данные из резервной копии JSON",
  "exportFailed": "Не удалось выполнить экспорт.",
  "couldntReadFile": "Не удалось прочитать файл.",
  "invalidBackupFile": "Это не похоже на резервную копию Habbits.",

  "replaceTitle": "Заменить все данные?",
  "replaceBody": "Все текущие привычки и история будут заменены содержимым файла ({count, plural, one{{count} привычка} few{{count} привычки} many{{count} привычек} other{{count} привычки}}). Это действие необратимо.",
  "cancel": "Отмена",
  "replace": "Заменить",
  "importFailed": "Не удалось импортировать. Ваши данные не изменены.",
  "importedHabits": "{count, plural, one{Импортирована {count} привычка} few{Импортировано {count} привычки} many{Импортировано {count} привычек} other{Импортировано {count} привычки}}",

  "language": "Язык",
  "languageSystem": "Системный",

  "noHabits": "Пока нет привычек. Нажмите +, чтобы добавить.",
  "homeError": "Ошибка: {error}",
  "streakLabel": "Серия: {count}",

  "thirtyDayLabel": "30 дней: {value}",
  "reminderTitle": "Напоминание",
  "reminderOff": "Выкл.",
  "rename": "Переименовать",
  "delete": "Удалить",

  "newHabit": "Новая привычка",
  "renameHabit": "Переименовать привычку",
  "nameLabel": "Название",
  "save": "Сохранить",
  "deleteHabitTitle": "Удалить «{name}»?",
  "deleteHabitBody": "Привычка и вся история отметок будут удалены без возможности восстановления.",

  "todayPrefix": "Сегодня · {date}",

  "reminderBody": "Пора отметиться"
}
```

- [ ] **Step 5: Fetch deps and generate localizations**

Run:
```bash
export PATH="/opt/homebrew/bin:$PATH"
flutter pub get
flutter gen-l10n
```
Expected: `flutter pub get` resolves with `shared_preferences`, `flutter_localizations`, `intl`; `flutter gen-l10n` prints nothing on success and creates `lib/l10n/app_localizations.dart` (+ `_en`/`_ru`).

- [ ] **Step 6: Verify generation and analysis**

Run:
```bash
ls lib/l10n/app_localizations*.dart
flutter analyze
```
Expected: three generated files listed; `flutter analyze` → "No issues found!" (nothing imports them yet).

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock l10n.yaml lib/l10n/
git commit -m "feat(i18n): add gen-l10n infra + en/ru ARB resources

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: AppLocale + LocaleController (shared_preferences-backed)

**Files:**
- Create: `lib/state/locale_controller.dart`
- Generated (committed): `lib/state/locale_controller.g.dart`
- Test: `test/state/locale_controller_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/state/locale_controller_test.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/state/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fromStorage falls back to system on null/unknown', () {
    expect(AppLocale.fromStorage(null), AppLocale.system);
    expect(AppLocale.fromStorage('xx'), AppLocale.system);
    expect(AppLocale.fromStorage('ru'), AppLocale.ru);
    expect(AppLocale.fromStorage('en'), AppLocale.en);
  });

  test('defaults to system when nothing stored', () async {
    final c = await _container({});
    expect(c.read(localeControllerProvider), AppLocale.system);
  });

  test('reads a persisted value', () async {
    final c = await _container({'locale': 'ru'});
    expect(c.read(localeControllerProvider), AppLocale.ru);
  });

  test('set persists to prefs and updates state', () async {
    final c = await _container({});
    await c.read(localeControllerProvider.notifier).set(AppLocale.en);
    expect(c.read(localeControllerProvider), AppLocale.en);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('locale'), 'en');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
export PATH="/opt/homebrew/bin:$PATH"
flutter test test/state/locale_controller_test.dart
```
Expected: FAIL — `locale_controller.dart` / `sharedPreferencesProvider` don't exist (compile error).

- [ ] **Step 3: Write the implementation**

Create `lib/state/locale_controller.dart`:
```dart
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'locale_controller.g.dart';

/// The user's language choice. [system] follows the device locale.
enum AppLocale {
  system('system', null),
  en('en', Locale('en')),
  ru('ru', Locale('ru'));

  const AppLocale(this.storage, this.locale);

  /// Stable token persisted to shared_preferences.
  final String storage;

  /// The forced locale, or null for [system] (let Flutter resolve the device).
  final Locale? locale;

  static AppLocale fromStorage(String? value) => AppLocale.values
      .firstWhere((e) => e.storage == value, orElse: () => AppLocale.system);
}

/// The loaded SharedPreferences instance. Overridden in `main()` after the async
/// load, mirroring how `notificationServiceProvider` is overridden.
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main');

/// Holds the selected [AppLocale], backed by shared_preferences.
@Riverpod(keepAlive: true)
class LocaleController extends _$LocaleController {
  static const _key = 'locale';

  @override
  AppLocale build() => AppLocale.fromStorage(
      ref.watch(sharedPreferencesProvider).getString(_key));

  Future<void> set(AppLocale value) async {
    await ref.read(sharedPreferencesProvider).setString(_key, value.storage);
    state = value;
  }
}
```

- [ ] **Step 4: Generate code**

Run:
```bash
export PATH="/opt/homebrew/bin:$PATH"
dart run build_runner build --delete-conflicting-outputs
```
Expected: succeeds; creates `lib/state/locale_controller.g.dart`.

- [ ] **Step 5: Run test to verify it passes**

Run:
```bash
flutter test test/state/locale_controller_test.dart
```
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/state/locale_controller.dart lib/state/locale_controller.g.dart test/state/locale_controller_test.dart
git commit -m "feat(i18n): AppLocale + shared_preferences-backed LocaleController

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Wire MaterialApp + main()

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Rewrite `lib/main.dart`**

Replace the whole file with:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';
import 'services/notification_service.dart';
import 'state/habit_providers.dart';
import 'state/locale_controller.dart';
import 'state/reminder_coordinator.dart';
import 'ui/habit_list/habit_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notifications = NotificationService();
  await notifications.init();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(notifications),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const HabbitsApp(),
    ),
  );
}

class HabbitsApp extends ConsumerWidget {
  const HabbitsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocale = ref.watch(localeControllerProvider);
    return MaterialApp(
      title: 'Habbits',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      locale: appLocale.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ReminderCoordinator(child: HabitListScreen()),
    );
  }
}
```

- [ ] **Step 2: Verify analyze + full suite still green**

Run:
```bash
export PATH="/opt/homebrew/bin:$PATH"
flutter analyze && flutter test
```
Expected: "No issues found!" and all existing tests PASS (no widget uses `AppLocalizations` yet; tests use their own `MaterialApp`).

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat(i18n): wire MaterialApp locale + delegates; load prefs in main

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Localize home list + name/delete dialogs

**Files:**
- Modify: `lib/ui/habit_list/habit_list_screen.dart`
- Modify: `lib/ui/widgets/habit_dialogs.dart`
- Test: `test/ui/habit_list_screen_test.dart`

- [ ] **Step 1: Add a failing Russian test**

In `test/ui/habit_list_screen_test.dart`:
1. Add import: `import 'package:habbits/l10n/app_localizations.dart';`
2. Add `import 'package:flutter/material.dart';` if not present.
3. Find the `_app(AppDatabase db)` helper. Add the localization args to its `MaterialApp` and give it an optional locale, so it becomes:
```dart
Widget _app(AppDatabase db, {Locale? locale}) => ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HabitListScreen(),
      ),
    );
```
(Keep whatever override list the file already had — only the `MaterialApp` changes; drop `const` if present.)
4. Add this test:
```dart
testWidgets('renders Russian copy when locale is ru', (tester) async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(_app(db, locale: const Locale('ru')));
  await tester.pumpAndSettle();
  expect(find.text('Пока нет привычек. Нажмите +, чтобы добавить.'),
      findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
export PATH="/opt/homebrew/bin:$PATH"
flutter test test/ui/habit_list_screen_test.dart
```
Expected: FAIL — the empty-state text is still the English literal.

- [ ] **Step 3: Localize `habit_list_screen.dart`**

Add import: `import 'package:habbits/l10n/app_localizations.dart';`
At the top of `build`, after getting `summaries`, add:
```dart
final l10n = AppLocalizations.of(context);
```
Replace literals:
- AppBar `IconButton` `tooltip: 'Settings'` → `tooltip: l10n.settings`
- Empty state `const Center(child: Text('No habits yet. Tap + to add one.'))` → `Center(child: Text(l10n.noHabits))`
- `error: (e, _) => Center(child: Text('Error: $e'))` → `error: (e, _) => Center(child: Text(l10n.homeError(e.toString())))`

In `_HabitCard.build` add `final l10n = AppLocalizations.of(context);` and replace:
- `Text('Streak: ${item.streak}')` → `Text(l10n.streakLabel(item.streak))`
Leave the percent `Text(percent == null ? '—' : '$percent%')` unchanged (digits only).
(The AppBar title `const Text('Habbits')` stays — brand name.)

- [ ] **Step 4: Localize `habit_dialogs.dart`**

Add import: `import 'package:habbits/l10n/app_localizations.dart';`
In `showHabitNameDialog`, inside the `builder: (ctx) =>`, add `final l10n = AppLocalizations.of(ctx);` and replace:
- `Text(habitId == null ? 'New habit' : 'Rename habit')` → `Text(habitId == null ? l10n.newHabit : l10n.renameHabit)`
- `const InputDecoration(labelText: 'Name')` → `InputDecoration(labelText: l10n.nameLabel)`
- Cancel button `const Text('Cancel')` → `Text(l10n.cancel)`
- Save button `const Text('Save')` → `Text(l10n.save)`
In `confirmDeleteHabit` builder add `final l10n = AppLocalizations.of(ctx);` and replace:
- `Text('Delete "$name"?')` → `Text(l10n.deleteHabitTitle(name))`
- the `const Text('This permanently deletes…')` body → `Text(l10n.deleteHabitBody)`
- Cancel `const Text('Cancel')` → `Text(l10n.cancel)`
- Delete `const Text('Delete')` → `Text(l10n.delete)`

- [ ] **Step 5: Run tests to verify pass**

Run:
```bash
flutter test test/ui/habit_list_screen_test.dart
```
Expected: PASS — the new `ru` test plus all existing English tests (English strings are unchanged).

- [ ] **Step 6: Commit**

```bash
git add lib/ui/habit_list/habit_list_screen.dart lib/ui/widgets/habit_dialogs.dart test/ui/habit_list_screen_test.dart
git commit -m "feat(i18n): localize home list and habit dialogs

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Localize Settings + add Language picker

**Files:**
- Modify: `lib/ui/settings/settings_screen.dart`
- Test: `test/ui/settings_screen_test.dart`

- [ ] **Step 1: Add failing tests (Russian title + language picker)**

In `test/ui/settings_screen_test.dart`:
1. Add imports: `import 'package:habbits/l10n/app_localizations.dart';` and (if missing) `import 'package:habbits/state/locale_controller.dart';`, `import 'package:shared_preferences/shared_preferences.dart';`.
2. Add localization args to every `MaterialApp` in the file (same three lines as Task 4 Step 1), and a `locale:` param where useful.
3. Ensure the `ProviderScope` overrides include a real prefs instance so the picker works. Add a helper at top of `main()`:
```dart
Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}
```
and include `sharedPreferencesProvider.overrideWithValue(await _prefs())` in the overrides for the picker test.
4. Add:
```dart
testWidgets('shows Russian settings title under ru locale', (tester) async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final prefs = await _prefs();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsScreen(),
    ),
  ));
  await tester.pumpAndSettle();
  expect(find.text('Настройки'), findsOneWidget);
  expect(find.text('Язык'), findsOneWidget);
});

testWidgets('language picker switches app to Russian', (tester) async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final prefs = await _prefs();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: Consumer(builder: (context, ref, _) {
      final loc = ref.watch(localeControllerProvider);
      return MaterialApp(
        locale: loc.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SettingsScreen(),
      );
    }),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('language-tile')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('lang-option-ru')));
  await tester.pumpAndSettle();
  expect(prefs.getString('locale'), 'ru');
  expect(find.text('Настройки'), findsOneWidget);
});
```

- [ ] **Step 2: Run to verify failure**

Run:
```bash
export PATH="/opt/homebrew/bin:$PATH"
flutter test test/ui/settings_screen_test.dart
```
Expected: FAIL — no `language-tile` key, title still English.

- [ ] **Step 3: Localize `settings_screen.dart` and add the picker**

Add imports:
```dart
import 'package:habbits/l10n/app_localizations.dart';
import '../../state/locale_controller.dart';
```
In `build`, add `final l10n = AppLocalizations.of(context);` and replace:
- `appBar: AppBar(title: const Text('Settings'))` → `appBar: AppBar(title: Text(l10n.settings))`
- export tile `title`/`subtitle` → `Text(l10n.exportTitle)` / `Text(l10n.exportSubtitle)`
- import tile `title`/`subtitle` → `Text(l10n.importTitle)` / `Text(l10n.importSubtitle)`

Append a third `ListTile` after the import tile (still inside the `ListView` children), showing the current selection and opening the picker:
```dart
Consumer(
  builder: (context, ref, _) {
    final current = ref.watch(localeControllerProvider);
    return ListTile(
      key: const Key('language-tile'),
      leading: const Icon(Icons.language),
      title: Text(l10n.language),
      subtitle: Text(_localeName(l10n, current)),
      onTap: () => _pickLanguage(context, ref, current),
    );
  },
),
```

Update the snackbar/dialog literals:
- `_export`: `const SnackBar(content: Text('Export failed.'))` → `SnackBar(content: Text(l10n.exportFailed))` (capture `l10n` before the await, since context is used after — read it at method entry: `final l10n = AppLocalizations.of(context);`).
- `_import` `on BackupFormatException`: replace `Text(e.message)` with `Text(l10n.invalidBackupFile)` (do not surface the raw English diagnostic).
- `_import` generic catch: `const SnackBar(content: Text("Couldn't read that file."))` → `SnackBar(content: Text(l10n.couldntReadFile))`.

> Each of `_export`/`_import` must capture `final l10n = AppLocalizations.of(context);` at the top, before the first `await`, to avoid using `context` across an async gap for localization.

In `confirmAndImport`, add `final l10n = AppLocalizations.of(context);` at the top and replace:
- dialog title `const Text('Replace all data?')` → `Text(l10n.replaceTitle)`
- body `Text('This will replace … (${data.habits.length} habits) …')` → `Text(l10n.replaceBody(data.habits.length))`
- Cancel `const Text('Cancel')` → `Text(l10n.cancel)`
- Replace `const Text('Replace')` → `Text(l10n.replace)`
- import-failed snackbar → `SnackBar(content: Text(l10n.importFailed))`
- success snackbar `Text('Imported ${data.habits.length} habits')` → `Text(l10n.importedHabits(data.habits.length))`

Add these top-level helpers at the bottom of the file:
```dart
String _localeName(AppLocalizations l10n, AppLocale locale) => switch (locale) {
      AppLocale.system => l10n.languageSystem,
      AppLocale.en => 'English',
      AppLocale.ru => 'Русский',
    };

Future<void> _pickLanguage(
  BuildContext context,
  WidgetRef ref,
  AppLocale current,
) async {
  final l10n = AppLocalizations.of(context);
  final chosen = await showDialog<AppLocale>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(l10n.language),
      children: [
        for (final option in AppLocale.values)
          RadioListTile<AppLocale>(
            key: Key('lang-option-${option.storage}'),
            value: option,
            groupValue: current,
            title: Text(_localeName(l10n, option)),
            onChanged: (v) => Navigator.pop(ctx, v),
          ),
      ],
    ),
  );
  if (chosen != null) {
    await ref.read(localeControllerProvider.notifier).set(chosen);
  }
}
```

- [ ] **Step 4: Run tests to verify pass**

Run:
```bash
flutter test test/ui/settings_screen_test.dart
```
Expected: PASS — both new tests plus existing English ones.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/settings/settings_screen.dart test/ui/settings_screen_test.dart
git commit -m "feat(i18n): localize Settings and add language picker

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Localize habit detail screen

**Files:**
- Modify: `lib/ui/habit_detail/habit_detail_screen.dart`
- Test: `test/ui/habit_detail_screen_test.dart`

- [ ] **Step 1: Add failing Russian test**

In `test/ui/habit_detail_screen_test.dart`:
1. Add import `import 'package:habbits/l10n/app_localizations.dart';` and (if missing) `import 'package:flutter/material.dart';`.
2. In the `app(AppDatabase db, int id)` helper, add the three localization args + an optional `Locale? locale` to its `MaterialApp` (same pattern as Task 4 Step 1).
3. Add:
```dart
testWidgets('detail shows Russian labels under ru locale', (tester) async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final id = await db.habitDao.createHabit(name: 'Читать', color: 1);
  await tester.pumpWidget(app(db, id, locale: const Locale('ru')));
  await tester.pumpAndSettle();
  expect(find.text('Напоминание'), findsOneWidget);
});
```
(Adjust the `app(...)` call to however the helper takes `locale` — e.g. `app(db, id, locale: const Locale('ru'))`.)

- [ ] **Step 2: Run to verify failure**

Run:
```bash
export PATH="/opt/homebrew/bin:$PATH"
flutter test test/ui/habit_detail_screen_test.dart
```
Expected: FAIL — "Напоминание" not found (still "Reminder").

- [ ] **Step 3: Localize `habit_detail_screen.dart`**

Add import `import 'package:habbits/l10n/app_localizations.dart';`.
In `build`, add `final l10n = AppLocalizations.of(context);` and replace:
- rename `IconButton` `tooltip: 'Rename'` → `tooltip: l10n.rename`
- delete `IconButton` `tooltip: 'Delete'` → `tooltip: l10n.delete`
- `Text('Streak: ${summary.streak}', …)` → `Text(l10n.streakLabel(summary.streak), …)`
- `Text('30-day: ${percent == null ? '—' : '$percent%'}', …)` →
  `Text(l10n.thirtyDayLabel(percent == null ? '—' : '$percent%'), …)`
- reminder `ListTile` `title: const Text('Reminder')` → `title: Text(l10n.reminderTitle)`
- (AppBar title stays `Text(summary.habit.name)` — user data.)

Change the `_reminderLabel` free function to take the localized "Off". Replace:
```dart
String _reminderLabel(BuildContext context, String? hhmm) {
  if (hhmm == null) return 'Off';
  return _toTimeOfDay(hhmm).format(context);
}
```
with:
```dart
String _reminderLabel(BuildContext context, String? hhmm) {
  if (hhmm == null) return AppLocalizations.of(context).reminderOff;
  return _toTimeOfDay(hhmm).format(context);
}
```

- [ ] **Step 4: Run tests to verify pass**

Run:
```bash
flutter test test/ui/habit_detail_screen_test.dart
```
Expected: PASS — new `ru` test plus existing English ones.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/habit_detail/habit_detail_screen.dart test/ui/habit_detail_screen_test.dart
git commit -m "feat(i18n): localize habit detail screen

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Locale-aware dates (recent days + heatmap), delete calendar_labels

**Files:**
- Modify: `lib/ui/widgets/recent_days_list.dart`
- Modify: `lib/ui/widgets/heatmap_grid.dart`
- Delete: `lib/domain/calendar_labels.dart`
- Test: `test/ui/recent_days_list_test.dart`

- [ ] **Step 1: Add a failing Russian date test**

In `test/ui/recent_days_list_test.dart`:
1. Add imports `import 'package:habbits/l10n/app_localizations.dart';` and `import 'package:intl/intl.dart';`.
2. Add the three localization args to the `host(...)` helper's `MaterialApp`, plus an optional `Locale? locale`.
3. Add:
```dart
testWidgets('formats the today row in Russian', (tester) async {
  final today = DateTime(2026, 6, 12); // Friday
  await tester.pumpWidget(host(
    onToggle: (_) {},
    done: const {},
    today: today,
    locale: const Locale('ru'),
  ));
  await tester.pumpAndSettle();
  final base = DateFormat.MMMEd('ru').format(today);
  expect(find.text('Сегодня · $base'), findsOneWidget);
});
```
(If the existing `host` helper doesn't accept `today`, thread it through the same way the other params are passed; the widget already takes a `today`.)

- [ ] **Step 2: Run to verify failure**

Run:
```bash
export PATH="/opt/homebrew/bin:$PATH"
flutter test test/ui/recent_days_list_test.dart
```
Expected: FAIL — label is still English ("Today · …") and uses the old formatter.

- [ ] **Step 3: Rewrite `recent_days_list.dart`**

Replace the imports block top:
```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:habbits/l10n/app_localizations.dart';
import '../../domain/dates.dart';
import '../../domain/recent_days.dart';
```
Replace `_label`:
```dart
String _label(BuildContext context, DateTime date) {
  final localeName = Localizations.localeOf(context).toString();
  final base = DateFormat.MMMEd(localeName).format(date);
  return date == dateOnly(today)
      ? AppLocalizations.of(context).todayPrefix(base)
      : base;
}
```
In `build`, change the `ListTile` title to pass context:
```dart
title: Text(_label(context, day.date)),
```

- [ ] **Step 4: Rewrite `heatmap_grid.dart` month labels**

Replace the imports block:
```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/dates.dart';
import '../../domain/heatmap.dart';
```
(Remove the `calendar_labels.dart` import.)
Replace `_monthLabels` and `_labelsRow` to take a locale name, and format with `DateFormat.MMM`:
```dart
List<String?> _monthLabels(String localeName) {
  final fmt = DateFormat.MMM(localeName);
  final labels = <String?>[];
  int? lastMonth;
  for (final week in data.weeks) {
    final m = week.first.date.month;
    if (m != lastMonth) {
      labels.add(fmt.format(DateTime(2000, m)));
      lastMonth = m;
    } else {
      labels.add(null);
    }
  }
  return labels;
}

Widget _labelsRow(String localeName) {
  final labels = _monthLabels(localeName);
  final labelHeight = cellSize * 0.75 * 1.4;
  return Padding(
    padding: EdgeInsets.only(bottom: cellGap),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final label in labels)
          SizedBox(
            width: cellSize + cellGap,
            height: labelHeight,
            child: label == null
                ? null
                : OverflowBox(
                    maxWidth: double.infinity,
                    maxHeight: labelHeight,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: TextStyle(fontSize: cellSize * 0.75),
                    ),
                  ),
          ),
      ],
    ),
  );
}
```
Update `build` to pass the locale name:
```dart
@override
Widget build(BuildContext context) {
  if (!showMonthLabels) return _grid();
  final localeName = Localizations.localeOf(context).toString();
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [_labelsRow(localeName), _grid()],
  );
}
```

- [ ] **Step 5: Delete `calendar_labels.dart` and verify no references**

Run:
```bash
rm lib/domain/calendar_labels.dart
export PATH="/opt/homebrew/bin:$PATH"
grep -rn "calendar_labels\|monthAbbr3\|weekdayAbbr3" lib test
```
Expected: no matches. If a `test/domain/calendar_labels_test.dart` exists, `git rm` it too.

- [ ] **Step 6: Run the date tests + analyze**

Run:
```bash
flutter test test/ui/recent_days_list_test.dart test/ui/heatmap_grid_test.dart
flutter analyze
```
Expected: PASS (English output of `DateFormat.MMMEd`/`DateFormat.MMM` matches the old `"Fri, Jun 12"` / `"Jun"`, so existing English assertions hold) and "No issues found!".

- [ ] **Step 7: Commit**

```bash
git add lib/ui/widgets/recent_days_list.dart lib/ui/widgets/heatmap_grid.dart test/ui/recent_days_list_test.dart
git rm lib/domain/calendar_labels.dart
git commit -m "feat(i18n): locale-aware dates via intl DateFormat; drop calendar_labels

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Localize reminder notification body

**Files:**
- Modify: `lib/services/notification_service.dart`
- Modify: `lib/state/reminder_coordinator.dart`

- [ ] **Step 1: Add a `body` parameter to `syncSchedule`**

In `lib/services/notification_service.dart`, change the signature and body literal:
```dart
Future<void> syncSchedule(
  List<ScheduledReminder> reminders, {
  required String body,
}) async {
  await _plugin.cancelAll();
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.defaultImportance,
    ),
    iOS: DarwinNotificationDetails(),
  );
  for (var i = 0; i < reminders.length; i++) {
    final r = reminders[i];
    await _plugin.zonedSchedule(
      id: i,
      title: r.habitName,
      body: body,
      scheduledDate: tz.TZDateTime.from(r.when, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}
```

- [ ] **Step 2: Pass the localized body from the coordinator + reschedule on locale change**

In `lib/state/reminder_coordinator.dart`:
1. Add imports:
```dart
import 'package:habbits/l10n/app_localizations.dart';
import 'locale_controller.dart';
```
2. In `initState`, add a listener so a language change re-syncs:
```dart
ref.listenManual(localeControllerProvider, (_, _) => _sync());
```
(place it next to the existing `ref.listenManual(habitSummariesProvider, …)`)
3. In `_sync`, resolve the localized body from the widget's context and pass it in. Guard on `mounted` because `_sync` can fire from a lifecycle/listener callback:
```dart
if (!mounted) return;
final body = AppLocalizations.of(context).reminderBody;
await service.syncSchedule(
  computeReminderSchedule(enabled, DateTime.now()),
  body: body,
);
```
(replace the existing final `await service.syncSchedule(...)` line.)

- [ ] **Step 3: Verify analyze + full suite**

Run:
```bash
export PATH="/opt/homebrew/bin:$PATH"
flutter analyze && flutter test
```
Expected: "No issues found!" and the full suite PASSES. (`ReminderCoordinator` is exercised via app composition; the home/detail tests don't mount it, so no test needs the new param besides the service call site, which is internal.)

- [ ] **Step 4: Commit**

```bash
git add lib/services/notification_service.dart lib/state/reminder_coordinator.dart
git commit -m "feat(i18n): localize reminder body; reschedule on language change

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Full verification + manual locale smoke test

**Files:** none (verification only)

- [ ] **Step 1: Full analyze + test**

Run:
```bash
export PATH="/opt/homebrew/bin:$PATH"
flutter analyze && flutter test
```
Expected: "No issues found!" and **all** tests pass.

- [ ] **Step 2: Confirm no stray English literals remain in localized widgets**

Run:
```bash
grep -rn "'Settings'\|'Reminder'\|'Cancel'\|'Save'\|'Delete'\|'Export data'\|'Import data'\|No habits yet\|Time to check in\|Streak:" lib --include='*.dart' | grep -v '.g.dart' | grep -v '/l10n/'
```
Expected: no matches outside generated files (the only `'Habbits'` left is the brand title in `main.dart`/home AppBar).

- [ ] **Step 3: Manual smoke test on a simulator/emulator**

Run (iOS sim already set up — see the `ios-build-setup` memory; or Android `habbits_test`):
```bash
flutter run -d habbits_ios
```
Verify: add a habit, open Settings → Language → Русский; the whole UI switches to Russian without restart; reopen the app (hot restart) and confirm it stays Russian (persisted); switch back to System/English. Check the detail screen's 30-day label, recent-days dates (`пт, 12 июн.`), and the delete dialog read naturally.

- [ ] **Step 4 (optional): Update the iOS/Android build memory if anything changed.** No commit needed for verification.

---

## Self-Review notes (for the executor)

- **Spec coverage:** infra (T1), persistence+controller (T2), MaterialApp wiring (T3), every user-facing screen (T4–T6), dates incl. the second `calendar_labels` consumer `heatmap_grid` (T7), notifications + reschedule-on-change (T8), tests embedded per task + final sweep (T9). Brand "Habbits" intentionally untranslated. Backup JSON keys untouched.
- **Plurals:** real ICU plurals only where there is a counted noun — `importedHabits` and `replaceBody`. `streakLabel`/`thirtyDayLabel`/home-percent are placeholder-only (no counted noun), matching the spec's clarification.
- **English output parity:** `DateFormat.MMMEd('en')` → `"Fri, Jun 12"` and `DateFormat.MMM('en')` → `"Jun"`, identical to the deleted constants, so existing English date assertions keep passing.
- **Async-gap safety:** Settings methods capture `l10n` before the first `await`; the coordinator guards `mounted` before reading context.

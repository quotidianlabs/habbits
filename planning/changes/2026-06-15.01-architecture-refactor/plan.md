---
status: shipped
date: 2026-06-15
slug: architecture-refactor
spec: architecture-refactor
pr: 86f0a38
---

# Layered Architecture Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure Habbits to Flutter's official layered/MVVM architecture, expressed with Riverpod idioms — repository layer, per-feature view models, feature-first UI + data-by-type — with zero behavior change.

**Architecture:** UI (views + `@riverpod` view models) → domain (pure functions + models) → data (repositories over services/DAOs). Views only watch their view model and call its commands; view models depend on repositories; repositories own the Drift DAO / `SharedPreferences` / `NotificationService`. Riverpod provides DI.

**Tech Stack:** Flutter 3.44, Riverpod codegen, Drift, intl, shared_preferences.

**Spec:** `docs/superpowers/specs/2026-06-15-architecture-refactor-design.md`

**Conventions:**
- `export PATH="/opt/homebrew/bin:$PATH"` before any flutter/dart command.
- After touching any `@riverpod`/`@Riverpod` class or function: `dart run build_runner build --delete-conflicting-outputs`.
- Generated code (`*.g.dart`) is committed.
- **Behavior-preserving:** every task ends with `flutter analyze` clean AND `flutter test` fully green (105 tests at start). If a test breaks for any reason other than a moved import or a deliberately relocated symbol, STOP and report.
- Repo prefers relative imports within `lib/` (e.g. `../../domain/...`).
- Each task is one commit with the given message.

**Pre-flight (run once before Task 1):**
```bash
export PATH="/opt/homebrew/bin:$PATH"
flutter analyze && flutter test   # confirm clean + 105 passing baseline
```

---

## Task 1: Extract domain models + split backup codec

**Files:**
- Create: `lib/domain/models/backup_data.dart`
- Create: `lib/domain/models/habit_with_dates.dart`
- Create: `lib/domain/models/habit_summary.dart`
- Create: `lib/domain/backup_codec.dart`
- Delete: `lib/domain/backup.dart`
- Modify: `lib/data/habit_dao.dart`, `lib/state/habit_providers.dart`, `lib/services/backup_service.dart`, and any importer of `domain/backup.dart` / `HabitWithDates` / `HabitSummary`.
- Test: move `test/domain/backup_test.dart` references; keep all green.

- [ ] **Step 1: Create `lib/domain/models/backup_data.dart`** (the model types + format exception, lifted verbatim from `backup.dart` lines 5–41):
```dart
/// One habit in a backup, with its completion dates inline.
class BackupHabit {
  const BackupHabit({
    required this.name,
    required this.color,
    required this.reminderTime,
    required this.sortOrder,
    required this.createdAt,
    required this.completions,
  });
  final String name;
  final int color;
  final String? reminderTime;
  final int sortOrder;
  final DateTime createdAt;
  final List<String> completions; // 'YYYY-MM-DD'
}

/// A full backup document.
class BackupData {
  const BackupData({
    required this.version,
    required this.exportedAt,
    required this.habits,
  });
  final int version;
  final DateTime exportedAt;
  final List<BackupHabit> habits;
}

/// Thrown when a file is not a valid Habbits backup. [message] is user-facing.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;
  @override
  String toString() => 'BackupFormatException: $message';
}
```

- [ ] **Step 2: Create `lib/domain/backup_codec.dart`** (the pure codec, lifted from `backup.dart` lines 1–3 + 43–151, now importing the models):
```dart
import 'dart:convert';

import 'models/backup_data.dart';

const int _currentVersion = 1;

/// Serializes [data] to a pretty JSON string.
String encodeBackup(BackupData data) {
  final map = {
    'app': 'habbits',
    'version': data.version,
    'exportedAt': data.exportedAt.toIso8601String(),
    'habits': [
      for (final h in data.habits)
        {
          'name': h.name,
          'color': h.color,
          'reminderTime': h.reminderTime,
          'sortOrder': h.sortOrder,
          'createdAt': h.createdAt.toIso8601String(),
          'completions': h.completions,
        },
    ],
  };
  return const JsonEncoder.withIndent('  ').convert(map);
}

/// Parses and strictly validates a backup string. Throws [BackupFormatException]
/// on anything invalid — never returns a partial result.
BackupData decodeBackup(String source) {
  final Object? root;
  try {
    root = jsonDecode(source);
  } catch (_) {
    throw const BackupFormatException('Not a valid JSON file.');
  }
  if (root is! Map<String, dynamic>) {
    throw const BackupFormatException('Not a valid Habbits backup file.');
  }
  if (root['app'] != 'habbits') {
    throw const BackupFormatException('This is not a Habbits backup file.');
  }
  final version = root['version'];
  if (version is! int || version != _currentVersion) {
    throw BackupFormatException('Unsupported backup version: ${root['version']}.');
  }
  final exportedRaw = root['exportedAt'];
  final exportedAt = exportedRaw is String ? DateTime.tryParse(exportedRaw) : null;
  if (exportedAt == null) {
    throw const BackupFormatException('Missing or invalid exportedAt.');
  }
  final habitsRaw = root['habits'];
  if (habitsRaw is! List) {
    throw const BackupFormatException('Backup is missing its habits list.');
  }
  final habits = [for (final item in habitsRaw) _decodeHabit(item)];
  return BackupData(version: version, exportedAt: exportedAt, habits: habits);
}

BackupHabit _decodeHabit(Object? item) {
  if (item is! Map<String, dynamic>) {
    throw const BackupFormatException('Invalid habit entry.');
  }
  final name = item['name'];
  if (name is! String || name.isEmpty) {
    throw const BackupFormatException('A habit is missing its name.');
  }
  final color = item['color'];
  if (color is! int) {
    throw BackupFormatException('Habit "$name" has an invalid color.');
  }
  final sortOrder = item['sortOrder'];
  if (sortOrder is! int) {
    throw BackupFormatException('Habit "$name" has an invalid sortOrder.');
  }
  final reminder = item['reminderTime'];
  if (reminder != null && reminder is! String) {
    throw BackupFormatException('Habit "$name" has an invalid reminderTime.');
  }
  final createdRaw = item['createdAt'];
  final createdAt = createdRaw is String ? DateTime.tryParse(createdRaw) : null;
  if (createdAt == null) {
    throw BackupFormatException('Habit "$name" has an invalid createdAt.');
  }
  final completionsRaw = item['completions'];
  if (completionsRaw is! List) {
    throw BackupFormatException('Habit "$name" has an invalid completions list.');
  }
  final completions = <String>[];
  for (final c in completionsRaw) {
    if (c is! String || !_isValidIsoDate(c)) {
      throw BackupFormatException('Habit "$name" has an invalid completion date: $c.');
    }
    completions.add(c);
  }
  return BackupHabit(
    name: name,
    color: color,
    reminderTime: reminder as String?,
    sortOrder: sortOrder,
    createdAt: createdAt,
    completions: completions,
  );
}

bool _isValidIsoDate(String s) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return false;
  final parts = s.split('-');
  final y = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  final d = int.parse(parts[2]);
  if (m < 1 || m > 12 || d < 1 || d > 31) return false;
  final dt = DateTime(y, m, d);
  return dt.year == y && dt.month == m && dt.day == d; // rejects e.g. 2026-02-30
}
```

- [ ] **Step 3: Delete `lib/domain/backup.dart`:** `git rm lib/domain/backup.dart`.

- [ ] **Step 4: Extract `HabitWithDates` to `lib/domain/models/habit_with_dates.dart`:**
```dart
import '../../data/database.dart';

/// A habit paired with the set of dates it was completed on.
class HabitWithDates {
  HabitWithDates(this.habit, this.dates);
  final Habit habit;
  final Set<DateTime> dates;
}
```
Then in `lib/data/habit_dao.dart`: remove the `HabitWithDates` class definition (lines 9–14) and add `import '../domain/models/habit_with_dates.dart';`. Update its `import '../domain/backup.dart';` → `import '../domain/models/backup_data.dart';`.

- [ ] **Step 5: Extract `HabitSummary` to `lib/domain/models/habit_summary.dart`:**
```dart
import '../../data/database.dart';

/// View-model value for one habit (home card and detail screen).
class HabitSummary {
  HabitSummary({
    required this.habit,
    required this.streak,
    required this.doneToday,
    required this.completionPercent,
    required this.dates,
  });
  final Habit habit;
  final int streak;
  final bool doneToday;

  /// 30-day completion percentage, or null when there is no window yet ("—").
  final int? completionPercent;

  /// All dates this habit was completed on (for the heatmap).
  final Set<DateTime> dates;
}
```
Then in `lib/state/habit_providers.dart`: remove the `HabitSummary` class (lines 12–30) and add `import '../domain/models/habit_summary.dart';`.

- [ ] **Step 6: Fix remaining importers.** Run:
```bash
export PATH="/opt/homebrew/bin:$PATH"
grep -rln "domain/backup.dart" lib test
```
For each hit, replace `import '.../domain/backup.dart';` with the codec and/or model import it actually needs:
- `lib/services/backup_service.dart` uses `buildBackup`/`encodeBackup`/`decodeBackup` + `BackupHabit`/`BackupData` → import both `'../domain/backup_codec.dart'` and `'../domain/models/backup_data.dart'`.
- `lib/ui/settings/settings_screen.dart` uses `BackupData`/`BackupFormatException` → `import '../../domain/models/backup_data.dart';`.
- `test/domain/backup_test.dart` → `import 'package:habbits/domain/backup_codec.dart';` + `import 'package:habbits/domain/models/backup_data.dart';`.
- `test/data/habit_dao_test.dart` and `test/services/backup_service_test.dart` → swap `backup.dart` for `models/backup_data.dart` (and `backup_codec.dart` if they call encode/decode).
Then build + verify:
```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```
Expected: analyze clean; all 105 tests pass.

- [ ] **Step 7: Commit**
```bash
git add lib/domain lib/data lib/state lib/services lib/ui test
git rm lib/domain/backup.dart 2>/dev/null; true
git commit -m "refactor(domain): extract models + split backup codec

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: SettingsRepository

**Files:**
- Create: `lib/data/repositories/settings_repository.dart` (+ generated `.g.dart`)
- Modify: `lib/state/locale_controller.dart` (depend on the repo; move `sharedPreferencesProvider` into the repo file)
- Modify: `lib/main.dart` (import path for `sharedPreferencesProvider`), `test/state/locale_controller_test.dart` (import path)
- Test: `test/data/repositories/settings_repository_test.dart`

- [ ] **Step 1: Write the failing repo test** — `test/data/repositories/settings_repository_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/repositories/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reads and writes the locale token', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SettingsRepository(await SharedPreferences.getInstance());
    expect(repo.readLocaleToken(), isNull);
    await repo.writeLocaleToken('ru');
    expect(repo.readLocaleToken(), 'ru');
  });

  test('reads a preexisting token', () async {
    SharedPreferences.setMockInitialValues({'locale': 'en'});
    final repo = SettingsRepository(await SharedPreferences.getInstance());
    expect(repo.readLocaleToken(), 'en');
  });
}
```

- [ ] **Step 2: Run it, expect failure**
```bash
export PATH="/opt/homebrew/bin:$PATH"
flutter test test/data/repositories/settings_repository_test.dart
```
Expected: FAIL (file/class doesn't exist).

- [ ] **Step 3: Create `lib/data/repositories/settings_repository.dart`** (also becomes the new home of `sharedPreferencesProvider`):
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'settings_repository.g.dart';

/// The loaded SharedPreferences instance; overridden in `main()`.
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main');

/// Persists app preferences (currently just the selected locale).
class SettingsRepository {
  SettingsRepository(this._prefs);
  final SharedPreferences _prefs;
  static const _localeKey = 'locale';

  String? readLocaleToken() => _prefs.getString(_localeKey);
  Future<void> writeLocaleToken(String token) =>
      _prefs.setString(_localeKey, token);
}

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) =>
    SettingsRepository(ref.watch(sharedPreferencesProvider));
```

- [ ] **Step 4: Update `lib/state/locale_controller.dart`** — remove its own `sharedPreferencesProvider` definition and the `shared_preferences` import; depend on the repository instead:
```dart
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/repositories/settings_repository.dart';

part 'locale_controller.g.dart';

/// The user's language choice. [system] follows the device locale.
enum AppLocale {
  system('system', null),
  en('en', Locale('en')),
  ru('ru', Locale('ru'));

  const AppLocale(this.storage, this.locale);
  final String storage;
  final Locale? locale;

  static AppLocale fromStorage(String? value) => AppLocale.values
      .firstWhere((e) => e.storage == value, orElse: () => AppLocale.system);
}

@Riverpod(keepAlive: true)
class LocaleController extends _$LocaleController {
  @override
  AppLocale build() => AppLocale.fromStorage(
      ref.watch(settingsRepositoryProvider).readLocaleToken());

  Future<void> set(AppLocale value) async {
    await ref.read(settingsRepositoryProvider).writeLocaleToken(value.storage);
    state = value;
  }
}
```

- [ ] **Step 5: Fix `sharedPreferencesProvider` importers.**
- `lib/main.dart`: change the import of `sharedPreferencesProvider` from `state/locale_controller.dart` to `data/repositories/settings_repository.dart` (add `import 'data/repositories/settings_repository.dart';`; keep `state/locale_controller.dart` for `localeControllerProvider`).
- `test/state/locale_controller_test.dart`: it overrides `sharedPreferencesProvider` — add `import 'package:habbits/data/repositories/settings_repository.dart';`. The controller tests still pass because `LocaleController.build` now reads through `SettingsRepository`, which reads the same `'locale'` key from the same overridden prefs.

- [ ] **Step 6: Generate, then run tests**
```bash
export PATH="/opt/homebrew/bin:$PATH"
dart run build_runner build --delete-conflicting-outputs
flutter test test/data/repositories/settings_repository_test.dart test/state/locale_controller_test.dart
flutter analyze
flutter test
```
Expected: new repo tests pass; locale tests pass; analyze clean; full suite green.

- [ ] **Step 7: Commit**
```bash
git add lib/data/repositories lib/state/locale_controller.dart lib/state/locale_controller.g.dart lib/main.dart test/data/repositories test/state/locale_controller_test.dart
git commit -m "refactor(data): add SettingsRepository; LocaleController depends on it

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: HabitRepository

**Files:**
- Create: `lib/data/repositories/habit_repository.dart` (+ generated `.g.dart`)
- Modify: `lib/state/habit_providers.dart` (source the summary stream from the repo; keep `appDatabaseProvider`/`habitDaoProvider` here for now)
- Test: `test/data/repositories/habit_repository_test.dart`

- [ ] **Step 1: Write the failing repo test** — `test/data/repositories/habit_repository_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/database.dart';
import 'package:habbits/data/repositories/habit_repository.dart';

void main() {
  late AppDatabase db;
  late HabitRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = HabitRepository(db.habitDao);
  });
  tearDown(() => db.close());

  test('create then watch returns the habit with its dates', () async {
    final id = await repo.createHabit(name: 'Read', color: 1);
    await repo.toggleCompletion(id, DateTime(2026, 6, 14));
    final rows = await repo.watchHabits().first;
    expect(rows.single.habit.name, 'Read');
    expect(rows.single.dates, {DateTime(2026, 6, 14)});
  });

  test('reorder rewrites order; delete removes', () async {
    final a = await repo.createHabit(name: 'A', color: 1);
    final b = await repo.createHabit(name: 'B', color: 1);
    await repo.reorderHabits([b, a]);
    var rows = await repo.getHabits();
    expect(rows.map((r) => r.habit.name), ['B', 'A']);
    await repo.deleteHabit(b);
    rows = await repo.getHabits();
    expect(rows.map((r) => r.habit.name), ['A']);
  });
}
```

- [ ] **Step 2: Run it, expect failure**
```bash
export PATH="/opt/homebrew/bin:$PATH"
flutter test test/data/repositories/habit_repository_test.dart
```
Expected: FAIL (class doesn't exist).

- [ ] **Step 3: Create `lib/data/repositories/habit_repository.dart`:**
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/models/backup_data.dart';
import '../../domain/models/habit_with_dates.dart';
import '../habit_dao.dart';
import '../../state/habit_providers.dart' show habitDaoProvider;

part 'habit_repository.g.dart';

/// The data-layer seam for all habit data. View models depend on this, never on
/// the DAO directly.
class HabitRepository {
  HabitRepository(this._dao);
  final HabitDao _dao;

  Stream<List<HabitWithDates>> watchHabits() => _dao.watchHabitsWithDates();
  Future<List<HabitWithDates>> getHabits() => _dao.getHabitsWithDates();
  Future<int> createHabit({required String name, required int color}) =>
      _dao.createHabit(name: name, color: color);
  Future<void> renameHabit(int id, String name) => _dao.renameHabit(id, name);
  Future<void> deleteHabit(int id) => _dao.deleteHabit(id);
  Future<void> toggleCompletion(int habitId, DateTime date) =>
      _dao.toggleCompletion(habitId, date);
  Future<void> reorderHabits(List<int> orderedIds) =>
      _dao.reorderHabits(orderedIds);
  Future<void> setReminderTime(int id, String? hhmm) =>
      _dao.setReminderTime(id, hhmm);
  Future<void> importReplace(List<BackupHabit> habits) =>
      _dao.importReplace(habits);
}

@Riverpod(keepAlive: true)
HabitRepository habitRepository(Ref ref) =>
    HabitRepository(ref.watch(habitDaoProvider));
```
> The `show habitDaoProvider` import is temporary; Task 8 relocates that provider and this import updates with it.

- [ ] **Step 4: Point the summary stream at the repository.** In `lib/state/habit_providers.dart`, change `habitSummaries` to read the repository instead of the DAO:
```dart
@riverpod
Stream<List<HabitSummary>> habitSummaries(Ref ref) {
  final repo = ref.watch(habitRepositoryProvider);
  return repo.watchHabits().map((rows) {
    final today = dateOnly(DateTime.now());
    return [
      for (final row in rows)
        HabitSummary(
          habit: row.habit,
          streak: currentStreak(row.dates, today),
          doneToday: row.dates.contains(today),
          completionPercent:
              completionPercent(row.dates, row.habit.createdAt, today),
          dates: row.dates,
        ),
    ];
  });
}
```
Add `import '../data/repositories/habit_repository.dart';`. Leave `appDatabaseProvider`, `habitDaoProvider`, `notificationServiceProvider`, and `habitDetail` as-is for now.

- [ ] **Step 5: Generate + verify**
```bash
export PATH="/opt/homebrew/bin:$PATH"
dart run build_runner build --delete-conflicting-outputs
flutter test test/data/repositories/habit_repository_test.dart
flutter analyze
flutter test
```
Expected: repo tests pass; analyze clean; full suite green (the home/detail screens still read `habitSummariesProvider`, now sourced via the repo — identical behavior).

- [ ] **Step 6: Commit**
```bash
git add lib/data/repositories/habit_repository.dart lib/data/repositories/habit_repository.g.dart lib/state/habit_providers.dart lib/state/habit_providers.g.dart test/data/repositories/habit_repository_test.dart
git commit -m "refactor(data): add HabitRepository over HabitDao

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: BackupRepository (move pure `buildBackup` to domain)

**Files:**
- Create: `lib/data/repositories/backup_repository.dart` (+ generated `.g.dart`)
- Modify: `lib/domain/backup_codec.dart` (add the pure `buildBackup`)
- Delete: `lib/services/backup_service.dart`
- Modify: `lib/ui/settings/settings_screen.dart` (call the repo via provider, not the free functions)
- Move/modify tests: `test/services/backup_service_test.dart` → `test/domain/backup_codec_test.dart` (it tests the pure `buildBackup`)

- [ ] **Step 1: Add pure `buildBackup` to `lib/domain/backup_codec.dart`** (moved verbatim from `backup_service.dart`; add imports it needs):
At the top, add imports:
```dart
import 'models/habit_with_dates.dart';
import 'dates.dart';
```
At the bottom, add:
```dart
/// Builds a [BackupData] snapshot from DAO rows. Pure (no I/O). Completion dates
/// are sorted ascending for a stable file.
BackupData buildBackup(List<HabitWithDates> rows, DateTime now) {
  return BackupData(
    version: 1,
    exportedAt: now,
    habits: [
      for (final r in rows)
        BackupHabit(
          name: r.habit.name,
          color: r.habit.color,
          reminderTime: r.habit.reminderTime,
          sortOrder: r.habit.sortOrder,
          createdAt: r.habit.createdAt,
          completions: (r.dates.toList()..sort()).map(formatIsoDate).toList(),
        ),
    ],
  );
}
```

- [ ] **Step 2: Create `lib/data/repositories/backup_repository.dart`:**
```dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/backup_codec.dart';
import '../../domain/dates.dart';
import '../../domain/models/backup_data.dart';
import 'habit_repository.dart';

part 'backup_repository.g.dart';

/// Orchestrates backup export/import over [HabitRepository] + file/share/picker.
class BackupRepository {
  BackupRepository(this._habits);
  final HabitRepository _habits;

  /// Writes the current data to a temp JSON file and opens the OS share sheet.
  Future<void> exportAndShare() async {
    final now = DateTime.now();
    final json = encodeBackup(buildBackup(await _habits.getHabits(), now));
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/habbits-backup-${formatIsoDate(now)}.json');
    await file.writeAsString(json);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: 'Habbits backup'),
    );
  }

  /// Lets the user pick a file and decodes it. Returns null if cancelled; throws
  /// [BackupFormatException] if the file is not a valid backup.
  Future<BackupData?> pickAndDecode() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    final path = result?.files.single.path;
    if (path == null) return null;
    return decodeBackup(await File(path).readAsString());
  }
}

@Riverpod(keepAlive: true)
BackupRepository backupRepository(Ref ref) =>
    BackupRepository(ref.watch(habitRepositoryProvider));
```

- [ ] **Step 3: Delete the old service:** `git rm lib/services/backup_service.dart`.

- [ ] **Step 4: Update `lib/ui/settings/settings_screen.dart`** to use the repository provider instead of the free functions:
- Replace `import '../../services/backup_service.dart';` with `import '../../data/repositories/backup_repository.dart';`.
- In `_export`: replace `await exportAndShare(ref.read(habitDaoProvider));` with `await ref.read(backupRepositoryProvider).exportAndShare();`.
- In `_import`: replace `data = await pickAndDecode();` with `data = await ref.read(backupRepositoryProvider).pickAndDecode();`.
- In `confirmAndImport`: replace `await ref.read(habitDaoProvider).importReplace(data.habits);` with `await ref.read(habitRepositoryProvider).importReplace(data.habits);` and add `import '../../data/repositories/habit_repository.dart';`. (You may now be able to drop the `habitDaoProvider` import from this file if nothing else uses it — check and remove if unused.)
- Keep `BackupData`/`BackupFormatException` import (`../../domain/models/backup_data.dart`).

- [ ] **Step 5: Relocate the pure-build test.** `git mv test/services/backup_service_test.dart test/domain/backup_codec_test.dart`. Open it: it tests `buildBackup` (pure). Update imports to `import 'package:habbits/domain/backup_codec.dart';` and `import 'package:habbits/domain/models/backup_data.dart';` (+ `habit_with_dates.dart`/`database.dart` if it constructs rows). Do NOT try to unit-test `exportAndShare`/`pickAndDecode` (they need platform plugins) — those are exercised via the settings widget test.

- [ ] **Step 6: Generate + verify**
```bash
export PATH="/opt/homebrew/bin:$PATH"
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```
Expected: analyze clean; full suite green (settings widget test still drives `confirmAndImport`).

- [ ] **Step 7: Commit**
```bash
git add lib/data/repositories lib/domain/backup_codec.dart lib/ui/settings/settings_screen.dart test/domain
git rm lib/services/backup_service.dart 2>/dev/null; true
git commit -m "refactor(data): add BackupRepository; move buildBackup to domain

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: HabitListViewModel

**Files:**
- Create: `lib/ui/habit_list/habit_list_view_model.dart` (+ generated `.g.dart`)
- Modify: `lib/ui/habit_list/habit_list_screen.dart` (watch the VM; call its commands)
- Modify: `lib/state/habit_providers.dart` (the `habitSummaries` mapping moves into the VM; keep `habitDetail` for now)
- Test: `test/ui/habit_list/habit_list_view_model_test.dart`; update `test/ui/habit_list_screen_test.dart`

- [ ] **Step 1: Write the failing VM test** — `test/ui/habit_list/habit_list_view_model_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/database.dart';
import 'package:habbits/state/habit_providers.dart';
import 'package:habbits/ui/habit_list/habit_list_view_model.dart';

void main() {
  ProviderContainer makeContainer(AppDatabase db) {
    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('exposes summaries and toggleToday flips today', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = makeContainer(db);
    final id = await db.habitDao.createHabit(name: 'Read', color: 1);

    // Wait for the first non-loading value.
    await c.read(habitListViewModelProvider.future);
    await c.read(habitListViewModelProvider.notifier).toggleToday(id);
    final list = await c.read(habitListViewModelProvider.future);
    expect(list.single.doneToday, isTrue);
  });
}
```

- [ ] **Step 2: Run it, expect failure**
```bash
export PATH="/opt/homebrew/bin:$PATH"
flutter test test/ui/habit_list/habit_list_view_model_test.dart
```
Expected: FAIL (provider doesn't exist).

- [ ] **Step 3: Create `lib/ui/habit_list/habit_list_view_model.dart`** (the summary mapping moves here from `habit_providers`):
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repositories/habit_repository.dart';
import '../../domain/completion_stats.dart';
import '../../domain/dates.dart';
import '../../domain/models/habit_summary.dart';
import '../../domain/streak.dart';

part 'habit_list_view_model.g.dart';

/// View model for the home list: the summaries stream + check-off / reorder /
/// create commands. Depends only on [HabitRepository].
@riverpod
class HabitListViewModel extends _$HabitListViewModel {
  @override
  Stream<List<HabitSummary>> build() {
    final repo = ref.watch(habitRepositoryProvider);
    return repo.watchHabits().map((rows) {
      final today = dateOnly(DateTime.now());
      return [
        for (final row in rows)
          HabitSummary(
            habit: row.habit,
            streak: currentStreak(row.dates, today),
            doneToday: row.dates.contains(today),
            completionPercent:
                completionPercent(row.dates, row.habit.createdAt, today),
            dates: row.dates,
          ),
      ];
    });
  }

  Future<void> toggleToday(int habitId) =>
      ref.read(habitRepositoryProvider).toggleCompletion(habitId, dateOnly(DateTime.now()));

  Future<void> reorder(List<int> orderedIds) =>
      ref.read(habitRepositoryProvider).reorderHabits(orderedIds);

  Future<void> createHabit(String name, {required int color}) =>
      ref.read(habitRepositoryProvider).createHabit(name: name, color: color);
}
```

- [ ] **Step 4: Repoint `habitDetail` and remove the old `habitSummaries`.** In `lib/state/habit_providers.dart`:
- Delete the `habitSummaries` provider (now superseded by the VM).
- Change `habitDetail` to watch the VM's stream value:
```dart
@riverpod
HabitSummary? habitDetail(Ref ref, int habitId) {
  final summaries = ref.watch(habitListViewModelProvider).value;
  if (summaries == null) return null;
  for (final s in summaries) {
    if (s.habit.id == habitId) return s;
  }
  return null;
}
```
- Add `import '../ui/habit_list/habit_list_view_model.dart';`. Keep `appDatabaseProvider`, `habitDaoProvider`, `notificationServiceProvider`.
- Update `lib/state/reminder_coordinator.dart`: it does `ref.read(habitSummariesProvider)` / `ref.listenManual(habitSummariesProvider, …)`. Replace both `habitSummariesProvider` references with `habitListViewModelProvider` and add `import '../ui/habit_list/habit_list_view_model.dart';`. (The value type is the same `AsyncValue<List<HabitSummary>>`.)

- [ ] **Step 5: Update the home screen to use the VM.** In `lib/ui/habit_list/habit_list_screen.dart`:
- Add `import 'habit_list_view_model.dart';`. Keep the l10n + reorder-domain imports.
- Change `final summaries = ref.watch(habitSummariesProvider);` → `final summaries = ref.watch(habitListViewModelProvider);`.
- Remove `final dao = ref.read(habitDaoProvider);` in the `data:` builder; change the reorder callback body to:
```dart
onReorderItem: (oldIndex, newIndex) {
  final ids = [for (final it in items) it.habit.id];
  ref.read(habitListViewModelProvider.notifier)
      .reorder(reorderedIds(ids, oldIndex, newIndex));
},
```
- In `_HabitCard.build`: remove `final dao = ref.read(habitDaoProvider);`; change the checkbox `onChanged` to:
```dart
onChanged: (_) =>
    ref.read(habitListViewModelProvider.notifier).toggleToday(item.habit.id),
```
- In `lib/ui/widgets/habit_dialogs.dart` (`showHabitNameDialog`): the create path currently calls `dao.createHabit(...)`. Replace the `final dao = ref.read(habitDaoProvider);` + create/rename calls with view-model / repository calls:
  - create: `await ref.read(habitListViewModelProvider.notifier).createHabit(name, color: Colors.teal.toARGB32());`
  - rename: keep using the repository directly here (rename isn't a list command): `await ref.read(habitRepositoryProvider).renameHabit(habitId, name);`
  - Update imports: add `import '../habit_list/habit_list_view_model.dart';` and `import '../../data/repositories/habit_repository.dart';`; drop the `habitDaoProvider` import/usage. `confirmDeleteHabit` similarly: `await ref.read(habitRepositoryProvider).deleteHabit(habitId);`.

- [ ] **Step 6: Update the home widget test.** In `test/ui/habit_list_screen_test.dart`: it overrides `appDatabaseProvider` (unchanged) and asserts rendered text (unchanged). No assertion changes needed, but if it imported `habitSummariesProvider` directly, repoint to `habitListViewModelProvider`. Run after building.

- [ ] **Step 7: Generate + verify**
```bash
export PATH="/opt/homebrew/bin:$PATH"
dart run build_runner build --delete-conflicting-outputs
flutter test test/ui/habit_list/habit_list_view_model_test.dart test/ui/habit_list_screen_test.dart
flutter analyze
flutter test
```
Expected: VM test passes; home tests pass; analyze clean; full suite green.

- [ ] **Step 8: Commit**
```bash
git add lib/ui/habit_list lib/ui/widgets/habit_dialogs.dart lib/state test/ui/habit_list
git commit -m "refactor(ui): HabitListViewModel; home screen drops direct DAO access

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: HabitDetailViewModel

**Files:**
- Create: `lib/ui/habit_detail/habit_detail_view_model.dart` (+ generated `.g.dart`)
- Modify: `lib/ui/habit_detail/habit_detail_screen.dart`
- Modify: `lib/state/habit_providers.dart` (move `habitDetail` into the VM or keep as the VM's source — see step)
- Test: `test/ui/habit_detail/habit_detail_view_model_test.dart`; update `test/ui/habit_detail_screen_test.dart`

- [ ] **Step 1: Write the failing VM test** — `test/ui/habit_detail/habit_detail_view_model_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/database.dart';
import 'package:habbits/state/habit_providers.dart';
import 'package:habbits/ui/habit_detail/habit_detail_view_model.dart';

void main() {
  test('exposes the habit and rename updates it', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);
    final id = await db.habitDao.createHabit(name: 'Old', color: 1);

    // Prime the list stream the detail VM derives from.
    await c.read(habitListViewModelProvider.future);
    expect(c.read(habitDetailViewModelProvider(id))?.habit.name, 'Old');

    await c.read(habitDetailViewModelProvider(id).notifier).rename('New');
    await c.read(habitListViewModelProvider.future);
    expect(c.read(habitDetailViewModelProvider(id))?.habit.name, 'New');
  });
}
```
> If `habitListViewModelProvider` isn't imported transitively, add `import 'package:habbits/ui/habit_list/habit_list_view_model.dart';`.

- [ ] **Step 2: Run it, expect failure**
```bash
export PATH="/opt/homebrew/bin:$PATH"
flutter test test/ui/habit_detail/habit_detail_view_model_test.dart
```
Expected: FAIL.

- [ ] **Step 3: Create `lib/ui/habit_detail/habit_detail_view_model.dart`** (a family Notifier deriving from the list VM, exposing commands):
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repositories/habit_repository.dart';
import '../../domain/models/habit_summary.dart';
import '../habit_list/habit_list_view_model.dart';

part 'habit_detail_view_model.g.dart';

/// View model for a single habit's detail screen. State derives from the list
/// view model; commands go through [HabitRepository].
@riverpod
class HabitDetailViewModel extends _$HabitDetailViewModel {
  @override
  HabitSummary? build(int habitId) {
    final summaries = ref.watch(habitListViewModelProvider).value;
    if (summaries == null) return null;
    for (final s in summaries) {
      if (s.habit.id == habitId) return s;
    }
    return null;
  }

  Future<void> toggle(DateTime date) =>
      ref.read(habitRepositoryProvider).toggleCompletion(habitId, date);
  Future<void> rename(String name) =>
      ref.read(habitRepositoryProvider).renameHabit(habitId, name);
  Future<void> delete() => ref.read(habitRepositoryProvider).deleteHabit(habitId);
  Future<void> setReminder(String? hhmm) =>
      ref.read(habitRepositoryProvider).setReminderTime(habitId, hhmm);
}
```

- [ ] **Step 4: Remove the now-redundant `habitDetail` provider** from `lib/state/habit_providers.dart` (the VM replaces it). Search for `habitDetailProvider` usages: `grep -rn "habitDetailProvider" lib test`. The only user is `habit_detail_screen.dart` — repoint it in the next step.

- [ ] **Step 5: Update `lib/ui/habit_detail/habit_detail_screen.dart`:**
- Replace `import '../../state/habit_providers.dart';` usage of `habitDetailProvider` with `import 'habit_detail_view_model.dart';`; change `final summary = ref.watch(habitDetailProvider(habitId));` → `final summary = ref.watch(habitDetailViewModelProvider(habitId));`.
- Remove `final dao = ref.read(habitDaoProvider);`. Replace the reminder/toggle calls:
  - `RecentDaysList(... onToggle: (date) => dao.toggleCompletion(habitId, date))` → `onToggle: (date) => ref.read(habitDetailViewModelProvider(habitId).notifier).toggle(date)`.
- In the free helpers `_onReminderToggle` / `_pickReminderTime`: they currently do `ref.read(habitDaoProvider).setReminderTime(...)` / `dao.setReminderTime(...)`. Change those to `ref.read(habitDetailViewModelProvider(habitId).notifier).setReminder(...)`. (These helpers already receive `ref` and `habitId`.)
- `confirmDeleteHabit`/`showHabitNameDialog` for rename are invoked from this screen via `habit_dialogs.dart`; those were repointed in Task 5 to the repository — leave as is, OR for the detail rename pass the detail VM. Keep the Task-5 repository calls (rename/delete through `habitRepositoryProvider`) to avoid extra coupling; the detail screen still works.
- Drop the `habitDaoProvider`/`habit_providers.dart` import if now unused.

- [ ] **Step 6: Update `test/ui/habit_detail_screen_test.dart`** — repoint any `habitDetailProvider` references to `habitDetailViewModelProvider`; overrides (`appDatabaseProvider`) and assertions unchanged. (The l10n delegates added earlier stay.)

- [ ] **Step 7: Generate + verify**
```bash
export PATH="/opt/homebrew/bin:$PATH"
dart run build_runner build --delete-conflicting-outputs
flutter test test/ui/habit_detail/habit_detail_view_model_test.dart test/ui/habit_detail_screen_test.dart
flutter analyze
flutter test
```
Expected: all green; analyze clean.

- [ ] **Step 8: Commit**
```bash
git add lib/ui/habit_detail lib/state test/ui/habit_detail
git commit -m "refactor(ui): HabitDetailViewModel; detail screen drops direct DAO access

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: SettingsViewModel

**Files:**
- Create: `lib/ui/settings/settings_view_model.dart` (+ generated `.g.dart`)
- Modify: `lib/ui/settings/settings_screen.dart`
- Test: update `test/ui/settings_screen_test.dart` (existing tests must stay green)

- [ ] **Step 1: Create `lib/ui/settings/settings_view_model.dart`** (command-only Notifier; `export`/`pickImport` go to `BackupRepository`, `applyImport` to `HabitRepository`):
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repositories/backup_repository.dart';
import '../../data/repositories/habit_repository.dart';
import '../../domain/models/backup_data.dart';

part 'settings_view_model.g.dart';

/// Commands for the settings screen's data-management actions. The view keeps
/// ownership of snackbars/dialogs; this exposes the operations they call.
@riverpod
class SettingsViewModel extends _$SettingsViewModel {
  @override
  void build() {}

  Future<void> export() => ref.read(backupRepositoryProvider).exportAndShare();

  /// Returns the decoded backup, or null if the user cancelled. Throws
  /// [BackupFormatException] on an invalid file (the view maps it to a message).
  Future<BackupData?> pickImport() =>
      ref.read(backupRepositoryProvider).pickAndDecode();

  Future<void> applyImport(BackupData data) =>
      ref.read(habitRepositoryProvider).importReplace(data.habits);
}
```
> If the Riverpod generator rejects `void build()` for a Notifier in this version, report it — the fallback is a plain `@riverpod SettingsViewModel settingsViewModel(Ref ref) => SettingsViewModel(ref);` function provider with a class holding `ref`, and the screen calls `ref.read(settingsViewModelProvider).export()` (no `.notifier`). Prefer the Notifier form if it generates cleanly.

- [ ] **Step 2: Update `lib/ui/settings/settings_screen.dart`** to call the VM:
- Add `import 'settings_view_model.dart';`.
- `_export`: `await ref.read(settingsViewModelProvider.notifier).export();` (drop the direct `backupRepositoryProvider` call).
- `_import`: `data = await ref.read(settingsViewModelProvider.notifier).pickImport();` (keep the same `try/on BackupFormatException/catch` + snackbars in the view).
- `confirmAndImport`: `await ref.read(settingsViewModelProvider.notifier).applyImport(data);` (replace the `habitRepositoryProvider.importReplace` call). You can now drop the direct `backup_repository`/`habit_repository` imports from the screen if unused; keep `backup_data.dart` for the `BackupData`/`BackupFormatException` types.
- The language picker (`_pickLanguage`) keeps using `localeControllerProvider` — unchanged.

- [ ] **Step 3: Generate + verify**
```bash
export PATH="/opt/homebrew/bin:$PATH"
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test test/ui/settings_screen_test.dart
flutter test
```
Expected: settings tests still pass (the confirm-import widget test now flows view → VM → repo → DAO); analyze clean; full suite green.

- [ ] **Step 4: Commit**
```bash
git add lib/ui/settings test/ui/settings_screen_test.dart
git commit -m "refactor(ui): SettingsViewModel for export/import commands

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Physical reorg into the final tree

Now all the new seams exist; relocate the remaining pre-existing files into the target layout, extract two widgets, and delete the emptied directories. This is mechanical: `git mv` + import fixes, gated by analyze + the full suite.

**Moves:**
- `lib/data/database.dart` → `lib/data/services/database/database.dart`
- `lib/data/habit_dao.dart` → `lib/data/services/database/habit_dao.dart`
- `lib/services/notification_service.dart` → `lib/data/services/notification_service.dart`
- `lib/state/locale_controller.dart` → `lib/ui/core/locale_controller.dart`
- `lib/state/reminder_coordinator.dart` → `lib/ui/core/reminder_coordinator.dart`
- Test mirrors: `test/data/database_test.dart` → `test/data/services/database/database_test.dart`; `test/data/habit_dao_test.dart` → `test/data/services/database/habit_dao_test.dart`; `test/state/locale_controller_test.dart` → `test/ui/core/locale_controller_test.dart`.

- [ ] **Step 1: Move the data sources.**
```bash
cd /Users/kevinsmith/src/habbits
mkdir -p lib/data/services/database
git mv lib/data/database.dart lib/data/services/database/database.dart
git mv lib/data/habit_dao.dart lib/data/services/database/habit_dao.dart
git mv lib/services/notification_service.dart lib/data/services/notification_service.dart
mkdir -p test/data/services/database
git mv test/data/database_test.dart test/data/services/database/database_test.dart
git mv test/data/habit_dao_test.dart test/data/services/database/habit_dao_test.dart
```
The Drift `part 'database.g.dart';` / `part 'habit_dao.g.dart';` move with their files; the generated parts sit beside them — run build_runner (Step 5) to regenerate in place. Delete stale generated parts if they remain at the old path: `git rm lib/data/database.g.dart lib/data/habit_dao.g.dart 2>/dev/null; true`.

- [ ] **Step 2: Dissolve `lib/state/`.** Move the two app-level files and relocate the leftover infra providers:
```bash
mkdir -p lib/ui/core
git mv lib/state/locale_controller.dart lib/ui/core/locale_controller.dart
git mv lib/state/locale_controller.g.dart lib/ui/core/locale_controller.g.dart
git mv lib/state/reminder_coordinator.dart lib/ui/core/reminder_coordinator.dart
mkdir -p test/ui/core
git mv test/state/locale_controller_test.dart test/ui/core/locale_controller_test.dart
```
`lib/state/habit_providers.dart` now only holds `appDatabaseProvider`, `habitDaoProvider`, `notificationServiceProvider`. Move these next to their owners:
- Put `appDatabaseProvider` and `habitDaoProvider` into a new `lib/data/services/database/database_providers.dart`:
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'database.dart';
import 'habit_dao.dart';

part 'database_providers.g.dart';

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

@riverpod
HabitDao habitDao(Ref ref) => ref.watch(appDatabaseProvider).habitDao;
```
- Put `notificationServiceProvider` into `lib/data/services/notification_service.dart` (append the provider + `part`/imports), or a sibling `notification_providers.dart`. Append to `notification_service.dart`:
```dart
// at top: import 'package:riverpod_annotation/riverpod_annotation.dart';
// and add `part 'notification_service.g.dart';`
@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) => throw UnimplementedError(
    'notificationServiceProvider must be overridden in main');
```
- `git rm lib/state/habit_providers.dart lib/state/habit_providers.g.dart`. Remove the empty `lib/state/` and `lib/services/` dirs and `test/state/` (git removes dirs when empty after the moves; verify with `git status`).

- [ ] **Step 3: Extract `theme.dart` and `HabitCard`.**
- Create `lib/ui/core/theme.dart`:
```dart
import 'package:flutter/material.dart';

ThemeData habbitsTheme() =>
    ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true);
```
In `lib/main.dart`, replace `theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),` with `theme: habbitsTheme(),` and add `import 'ui/core/theme.dart';`.
- Create `lib/ui/habit_list/widgets/habit_card.dart`: move the entire `_HabitCard` class out of `habit_list_screen.dart` into it as a public `HabitCard` (rename `_HabitCard` → `HabitCard`, keep `super.key`). Carry its imports (material, flutter_riverpod, dates, l10n, day_strip, habit_list_view_model). In `habit_list_screen.dart`, delete the `_HabitCard` class, add `import 'widgets/habit_card.dart';`, and change the child construction `_HabitCard(...)` → `HabitCard(...)`.

- [ ] **Step 4: Fix all imports repo-wide.** After the moves, many relative imports are stale. Find and fix:
```bash
export PATH="/opt/homebrew/bin:$PATH"
grep -rln "state/habit_providers\|state/locale_controller\|state/reminder_coordinator\|services/notification_service\|data/database.dart\|data/habit_dao.dart" lib test
```
For each file, repoint imports to the new paths:
- `'../data/database.dart'` / `'../../data/database.dart'` → `.../data/services/database/database.dart`
- `habit_dao.dart` → `.../data/services/database/habit_dao.dart`
- `services/notification_service.dart` → `data/services/notification_service.dart`
- `state/locale_controller.dart` → `ui/core/locale_controller.dart`
- `state/reminder_coordinator.dart` → `ui/core/reminder_coordinator.dart`
- `state/habit_providers.dart` (for `appDatabaseProvider`/`habitDaoProvider`) → `data/services/database/database_providers.dart`; (for `notificationServiceProvider`) → `data/services/notification_service.dart`.
- `habit_repository.dart`'s temporary `import '../../state/habit_providers.dart' show habitDaoProvider;` → `import '../services/database/database_providers.dart' show habitDaoProvider;` (or import `database_providers.dart` normally).
- `main.dart`, test files (`appDatabaseProvider` overrides, `database.dart` imports for `AppDatabase`/`NativeDatabase`) — update to the new paths.

- [ ] **Step 5: Regenerate + verify**
```bash
export PATH="/opt/homebrew/bin:$PATH"
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```
Expected: analyze clean; full suite green. Resolve any remaining unresolved-import or missing-`part` errors the analyzer reports, then re-run until clean.

- [ ] **Step 6: Confirm the old dirs are gone**
```bash
ls lib/state lib/services 2>&1   # expect: No such file or directory
git status --short
```

- [ ] **Step 7: Commit**
```bash
git add -A
git commit -m "refactor(structure): move files into final layered tree; extract theme + HabitCard

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Final verification + smoke test

**Files:** none (verification only)

- [ ] **Step 1: Full analyze + test**
```bash
export PATH="/opt/homebrew/bin:$PATH"
flutter analyze && flutter test
```
Expected: "No issues found!" and all tests pass (≥105 plus the new repository/view-model tests).

- [ ] **Step 2: Confirm the target structure**
```bash
find lib -name '*.dart' ! -name '*.g.dart' ! -path '*/l10n/*' | sort
```
Expected layout: `ui/core/{locale_controller,reminder_coordinator,theme}.dart`; `ui/<feature>/{<screen>,<view_model>}.dart` (+ `habit_list/widgets/habit_card.dart`); `ui/widgets/*`; `domain/models/*`, `domain/*` pure functions, `domain/backup_codec.dart`; `data/repositories/{habit,settings,backup}_repository.dart`; `data/services/notification_service.dart`, `data/services/database/{database,habit_dao,database_providers}.dart`. No `lib/state/` or `lib/services/`.

- [ ] **Step 3: Confirm no widget reaches into the data layer.** A view should not import a repository, DAO, or `database.dart` directly (it goes through its view model). Spot-check:
```bash
grep -rn "habitDaoProvider\|habitRepositoryProvider\|backupRepositoryProvider\|database.dart" lib/ui --include='*.dart' | grep -v 'view_model' | grep -v '/core/'
```
Expected: empty (only view models / `ui/core` infra reference data-layer providers). If `habit_dialogs.dart` still references a repository, that's acceptable (it's a shared action widget), but prefer routing through a view model; note any deliberate exception.

- [ ] **Step 4: Manual smoke test** on the iOS simulator (see the `ios-build-setup` memory) or Android `habbits_test`:
```bash
flutter run -d habbits_ios
```
Verify nothing regressed: add a habit, check it off (streak updates), open detail, set a reminder, reorder on the home list, open Settings → export and import, switch language. All must behave exactly as before.

- [ ] **Step 5 (optional):** update `CLAUDE.md`/README architecture notes to describe the new layering, if desired. No commit required for verification.

---

## Self-Review notes (for the executor)

- **Spec coverage:** layers + Riverpod-MVVM mapping (Tasks 3/5/6/7 + provider wiring), folder structure (Task 8), data layer repositories (Tasks 2–4), per-feature view models (Tasks 5–7), domain models from Drift entities + backup split (Task 1), app-level `ui/core` + theme extraction (Task 8), migration sequence + tests-green invariant (every task), final verification (Task 9).
- **Behavior-preserving:** no ARB/string/feature changes; every task gates on full-suite green. Drift entities remain the habit model (no mappers).
- **Known cross-task seam:** `HabitRepository` temporarily imports `habitDaoProvider` from `state/habit_providers.dart` (Task 3) and is repointed to `database_providers.dart` in Task 8 — intentional, called out in both tasks.
- **Placeholder caution:** Task 7 Step 1 deliberately contains a wrong `applyImport` body that Step 2 replaces — do not commit between those steps; commit only after Step 2 yields the correct method.

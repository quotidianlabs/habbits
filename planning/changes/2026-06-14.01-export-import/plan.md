# JSON Export / Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Export all habits + completions to a versioned JSON file via the OS share sheet, and import a JSON backup that strictly validates then replaces all data in one transaction.

**Architecture:** A pure-Dart `domain/backup.dart` owns the JSON shape + validation (`encodeBackup`/`decodeBackup`, `BackupData`/`BackupHabit`, `BackupFormatException`). The DAO gains a one-shot read and a transactional `importReplace`. A `backup_service.dart` is the thin plugin glue (path_provider/share_plus/file_picker). A new Settings screen, reached from a home app-bar icon, wires the two actions with a replace-confirmation. No schema change.

**Tech Stack:** Flutter, Drift, Riverpod; `share_plus`, `file_picker`, `path_provider`.

**Source spec:** `docs/superpowers/specs/2026-06-14-export-import-design.md`.

**Pre-flight:** Flutter on PATH (`/opt/homebrew/bin`; `export PATH="/opt/homebrew/bin:$PATH"` if needed). Branch `feat/export-import` (confirm `git branch --show-current`; if detached, STOP).

**Existing interfaces:** `lib/domain/dates.dart` → `formatIsoDate`, `parseIsoDate`. `lib/data/habit_dao.dart` → `HabitDao` with `HabitWithDates{habit, dates}`, `watchHabitsWithDates()`, and the Drift `Habit` row (`.id`,`.name`,`.color` int,`.reminderTime` String?,`.sortOrder` int,`.createdAt` DateTime). `lib/state/habit_providers.dart` → `habitDaoProvider`, `appDatabaseProvider`.

---

### Task 1: Add packages

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add the three runtime packages**

```bash
flutter pub add share_plus file_picker path_provider
```
Expected: `pubspec.yaml` `dependencies:` lists all three; `flutter pub get` succeeds.

- [ ] **Step 2: Verify analyze + existing suite still pass**

```bash
flutter analyze
flutter test
```
Expected: `No issues found!`; all existing tests green (adding deps changes no behavior).

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add share_plus, file_picker, path_provider"
```

---

### Task 2: Backup format + validation (pure)

**Files:**
- Create: `lib/domain/backup.dart`
- Test: `test/domain/backup_test.dart`

- [ ] **Step 1: Write the failing test** — `test/domain/backup_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/backup.dart';

void main() {
  test('encode -> decode round-trips a backup', () {
    final data = BackupData(
      version: 1,
      exportedAt: DateTime.parse('2026-06-14T09:00:00.000'),
      habits: [
        BackupHabit(
          name: 'Read',
          color: 42,
          reminderTime: null,
          sortOrder: 0,
          createdAt: DateTime.parse('2026-06-01T08:00:00.000'),
          completions: const ['2026-06-01', '2026-06-02'],
        ),
        BackupHabit(
          name: 'Medicine',
          color: 99,
          reminderTime: '08:30',
          sortOrder: 1,
          createdAt: DateTime.parse('2026-05-20T07:00:00.000'),
          completions: const [],
        ),
      ],
    );

    final decoded = decodeBackup(encodeBackup(data));
    expect(decoded.version, 1);
    expect(decoded.habits, hasLength(2));
    final read = decoded.habits.first;
    expect(read.name, 'Read');
    expect(read.color, 42);
    expect(read.reminderTime, isNull);
    expect(read.sortOrder, 0);
    expect(read.createdAt, DateTime.parse('2026-06-01T08:00:00.000'));
    expect(read.completions, ['2026-06-01', '2026-06-02']);
    expect(decoded.habits[1].reminderTime, '08:30');
  });

  group('decodeBackup rejects invalid input', () {
    void expectReject(String src) =>
        expect(() => decodeBackup(src), throwsA(isA<BackupFormatException>()));

    test('non-JSON text', () => expectReject('not json at all'));
    test('a JSON array, not an object', () => expectReject('[]'));
    test('wrong app marker', () =>
        expectReject('{"app":"other","version":1,"exportedAt":"2026-06-14T00:00:00.000","habits":[]}'));
    test('unsupported version', () =>
        expectReject('{"app":"habbits","version":2,"exportedAt":"2026-06-14T00:00:00.000","habits":[]}'));
    test('missing habits list', () =>
        expectReject('{"app":"habbits","version":1,"exportedAt":"2026-06-14T00:00:00.000"}'));
    test('habit missing name', () => expectReject(
        '{"app":"habbits","version":1,"exportedAt":"2026-06-14T00:00:00.000","habits":[{"color":1,"sortOrder":0,"createdAt":"2026-06-01T00:00:00.000","completions":[]}]}'));
    test('habit with a malformed completion date', () => expectReject(
        '{"app":"habbits","version":1,"exportedAt":"2026-06-14T00:00:00.000","habits":[{"name":"X","color":1,"sortOrder":0,"createdAt":"2026-06-01T00:00:00.000","completions":["2026-13-40"]}]}'));
  });

  test('decodes an empty-habits backup', () {
    final decoded = decodeBackup(
        '{"app":"habbits","version":1,"exportedAt":"2026-06-14T00:00:00.000","habits":[]}');
    expect(decoded.habits, isEmpty);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/domain/backup_test.dart
```
Expected: FAIL — file/symbols undefined.

- [ ] **Step 3: Implement `lib/domain/backup.dart`**

```dart
import 'dart:convert';

const int _currentVersion = 1;

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

- [ ] **Step 4: Run to verify it passes**

```bash
flutter test test/domain/backup_test.dart
```
Expected: PASS (all cases).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/backup.dart test/domain/backup_test.dart
git commit -m "feat(domain): add backup encode/decode with strict validation"
```

---

### Task 3: DAO — one-shot read + transactional importReplace

**Files:**
- Modify: `lib/data/habit_dao.dart`
- Test: `test/data/habit_dao_test.dart`

Add a one-shot `getHabitsWithDates()` (the `.get()` form of the existing join, sharing a private grouping helper with the existing `watchHabitsWithDates()`), and `importReplace(List<BackupHabit>)` that wipes then loads inside a transaction.

- [ ] **Step 1: Add failing tests** — append inside the existing `main()` in `test/data/habit_dao_test.dart`:

```dart
  test('getHabitsWithDates returns all habits with their dates (one-shot)', () async {
    final id = await dao.createHabit(name: 'Read', color: 1);
    await dao.toggleCompletion(id, DateTime(2026, 6, 13));
    await dao.toggleCompletion(id, DateTime(2026, 6, 12));

    final rows = await dao.getHabitsWithDates();
    expect(rows.single.habit.name, 'Read');
    expect(rows.single.dates, {DateTime(2026, 6, 13), DateTime(2026, 6, 12)});
  });

  test('importReplace wipes existing data and loads the new set', () async {
    // Pre-existing data that must be gone after import.
    final old = await dao.createHabit(name: 'Old', color: 1);
    await dao.toggleCompletion(old, DateTime(2026, 6, 1));

    await dao.importReplace(const [
      BackupHabit(
        name: 'Medicine',
        color: 0xFF009688,
        reminderTime: '08:30',
        sortOrder: 0,
        createdAt: null, // replaced below — see note
        completions: ['2026-06-10', '2026-06-11'],
      ),
    ].map((h) => h).toList());

    final rows = await dao.getHabitsWithDates();
    expect(rows, hasLength(1));
    expect(rows.single.habit.name, 'Medicine');
    expect(rows.single.habit.reminderTime, '08:30');
    expect(rows.single.dates,
        {DateTime(2026, 6, 10), DateTime(2026, 6, 11)});
  });

  test('importReplace with an empty list clears everything', () async {
    await dao.createHabit(name: 'Gone', color: 1);
    await dao.importReplace(const []);
    expect(await dao.getHabitsWithDates(), isEmpty);
  });
```

NOTE: `BackupHabit.createdAt` is a non-null `DateTime`; the `null` above is a placeholder that will not compile. Replace that single test's habit with a real date — use this exact test body instead of the snippet above for the second test:

```dart
  test('importReplace wipes existing data and loads the new set', () async {
    final old = await dao.createHabit(name: 'Old', color: 1);
    await dao.toggleCompletion(old, DateTime(2026, 6, 1));

    await dao.importReplace([
      BackupHabit(
        name: 'Medicine',
        color: 0xFF009688,
        reminderTime: '08:30',
        sortOrder: 0,
        createdAt: DateTime(2026, 6, 5),
        completions: const ['2026-06-10', '2026-06-11'],
      ),
    ]);

    final rows = await dao.getHabitsWithDates();
    expect(rows, hasLength(1));
    expect(rows.single.habit.name, 'Medicine');
    expect(rows.single.habit.reminderTime, '08:30');
    expect(rows.single.dates, {DateTime(2026, 6, 10), DateTime(2026, 6, 11)});
  });
```

(Use the corrected version. Add `import 'package:habbits/domain/backup.dart';` to the test file's imports.)

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/data/habit_dao_test.dart
```
Expected: FAIL — `getHabitsWithDates`/`importReplace` undefined.

- [ ] **Step 3: Replace `lib/data/habit_dao.dart`**

```dart
import 'package:drift/drift.dart';

import '../domain/backup.dart';
import '../domain/dates.dart';
import 'database.dart';

part 'habit_dao.g.dart';

/// A habit paired with the set of dates it was completed on.
class HabitWithDates {
  HabitWithDates(this.habit, this.dates);
  final Habit habit;
  final Set<DateTime> dates;
}

@DriftAccessor(tables: [Habits, Completions])
class HabitDao extends DatabaseAccessor<AppDatabase> with _$HabitDaoMixin {
  HabitDao(super.db);

  Future<int> createHabit({required String name, required int color}) async {
    final existing = await select(habits).get();
    return into(habits).insert(HabitsCompanion.insert(
      name: name,
      color: color,
      sortOrder: existing.length,
      createdAt: DateTime.now(),
    ));
  }

  Future<void> renameHabit(int id, String name) {
    return (update(habits)..where((h) => h.id.equals(id)))
        .write(HabitsCompanion(name: Value(name)));
  }

  Future<void> deleteHabit(int id) {
    return (delete(habits)..where((h) => h.id.equals(id))).go();
  }

  /// Toggles a completion for [habitId] on [date]: inserts if absent, deletes if
  /// present. Idempotent with respect to the displayed state.
  Future<void> toggleCompletion(int habitId, DateTime date) async {
    final iso = formatIsoDate(date);
    final existing = await (select(completions)
          ..where((c) => c.habitId.equals(habitId) & c.localDate.equals(iso)))
        .getSingleOrNull();

    if (existing != null) {
      await (delete(completions)..where((c) => c.id.equals(existing.id))).go();
    } else {
      await into(completions).insert(CompletionsCompanion.insert(
        habitId: habitId,
        localDate: iso,
        createdAt: DateTime.now(),
      ));
    }
  }

  SimpleSelectStatement<$HabitsTable, Habit> _orderedHabitsJoin() =>
      select(habits)..orderBy([OrderingTerm(expression: habits.sortOrder)]);

  List<HabitWithDates> _group(List<TypedResult> rows) {
    final byId = <int, HabitWithDates>{};
    final order = <int>[];
    for (final row in rows) {
      final habit = row.readTable(habits);
      if (!byId.containsKey(habit.id)) {
        byId[habit.id] = HabitWithDates(habit, <DateTime>{});
        order.add(habit.id);
      }
      final completion = row.readTableOrNull(completions);
      if (completion != null) {
        byId[habit.id]!.dates.add(parseIsoDate(completion.localDate));
      }
    }
    return [for (final id in order) byId[id]!];
  }

  JoinedSelectStatement<HasResultSet, dynamic> _habitsWithDatesQuery() {
    return _orderedHabitsJoin().join([
      leftOuterJoin(completions, completions.habitId.equalsExp(habits.id)),
    ]);
  }

  /// Reactive stream of every habit with its completion dates, ordered by
  /// sortOrder.
  Stream<List<HabitWithDates>> watchHabitsWithDates() =>
      _habitsWithDatesQuery().watch().map(_group);

  /// One-shot read of every habit with its completion dates.
  Future<List<HabitWithDates>> getHabitsWithDates() async =>
      _group(await _habitsWithDatesQuery().get());

  /// Replaces ALL data with [data] in a single transaction: deletes every habit
  /// (FK cascade clears completions), then inserts each habit and its
  /// completions. Completion `created_at` is set to now (audit-only).
  Future<void> importReplace(List<BackupHabit> data) async {
    await transaction(() async {
      await delete(completions).go();
      await delete(habits).go();
      for (final h in data) {
        final id = await into(habits).insert(HabitsCompanion.insert(
          name: h.name,
          color: h.color,
          reminderTime: Value(h.reminderTime),
          sortOrder: h.sortOrder,
          createdAt: h.createdAt,
        ));
        for (final iso in h.completions) {
          await into(completions).insert(CompletionsCompanion.insert(
            habitId: id,
            localDate: iso,
            createdAt: DateTime.now(),
          ));
        }
      }
    });
  }
}
```

Notes: the `_orderedHabitsJoin`/`_habitsWithDatesQuery` types come from Drift's generated code; if the exact generic type annotations don't compile against the installed Drift version, simplify by inlining the query into both `watchHabitsWithDates` and `getHabitsWithDates` (each building `select(habits).join([...])..orderBy(...)`) and keep only the shared `_group(rows)` helper. The goal is: one grouping helper, two entry points. `importReplace` deletes completions explicitly before habits so it does not depend on cascade behavior.

- [ ] **Step 4: Run to verify it passes**

```bash
flutter test test/data/habit_dao_test.dart
```
Expected: PASS (existing DAO tests + 3 new).

- [ ] **Step 5: Commit**

```bash
git add lib/data/habit_dao.dart test/data/habit_dao_test.dart
git commit -m "feat(data): add one-shot read and transactional importReplace"
```

---

### Task 4: Backup service (build + share + pick) and the round-trip test

**Files:**
- Create: `lib/services/backup_service.dart`
- Test: `test/services/backup_service_test.dart`

`buildBackup` is pure and testable; `exportAndShare`/`pickAndDecode` are the plugin boundary (not unit-tested). The headline round-trip test lives here.

- [ ] **Step 1: Write the failing test** — `test/services/backup_service_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/database.dart';
import 'package:habbits/domain/backup.dart';
import 'package:habbits/services/backup_service.dart';

void main() {
  test('buildBackup snapshots habits with sorted completion dates', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final dao = db.habitDao;
    final id = await dao.createHabit(name: 'Read', color: 7);
    await dao.toggleCompletion(id, DateTime(2026, 6, 12));
    await dao.toggleCompletion(id, DateTime(2026, 6, 10));

    final data = buildBackup(await dao.getHabitsWithDates(),
        DateTime.parse('2026-06-14T09:00:00.000'));

    expect(data.version, 1);
    expect(data.habits.single.name, 'Read');
    expect(data.habits.single.color, 7);
    expect(data.habits.single.completions, ['2026-06-10', '2026-06-12']); // sorted
  });

  test('full round-trip: export -> encode -> decode -> import reproduces data',
      () async {
    final src = AppDatabase(NativeDatabase.memory());
    addTearDown(src.close);
    final a = await src.habitDao.createHabit(name: 'Medicine', color: 0xFF009688);
    await src.habitDao.toggleCompletion(a, DateTime(2026, 6, 10));
    await src.habitDao.toggleCompletion(a, DateTime(2026, 6, 11));
    final b = await src.habitDao.createHabit(name: 'Read', color: 0xFF3366CC);
    await src.habitDao.toggleCompletion(b, DateTime(2026, 6, 9));

    final json = encodeBackup(
        buildBackup(await src.habitDao.getHabitsWithDates(),
            DateTime.parse('2026-06-14T09:00:00.000')));

    // Restore into a fresh database.
    final dst = AppDatabase(NativeDatabase.memory());
    addTearDown(dst.close);
    await dst.habitDao.importReplace(decodeBackup(json).habits);

    final rows = await dst.habitDao.getHabitsWithDates();
    expect(rows.map((r) => r.habit.name), ['Medicine', 'Read']);
    expect(rows.map((r) => r.habit.color), [0xFF009688, 0xFF3366CC]);
    expect(rows[0].dates, {DateTime(2026, 6, 10), DateTime(2026, 6, 11)});
    expect(rows[1].dates, {DateTime(2026, 6, 9)});
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/services/backup_service_test.dart
```
Expected: FAIL — `backup_service.dart`/`buildBackup` undefined.

- [ ] **Step 3: Implement `lib/services/backup_service.dart`**

```dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/habit_dao.dart';
import '../domain/backup.dart';
import '../domain/dates.dart';

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

/// Writes the current data to a temp JSON file and opens the OS share sheet.
Future<void> exportAndShare(HabitDao dao) async {
  final now = DateTime.now();
  final json = encodeBackup(buildBackup(await dao.getHabitsWithDates(), now));
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/habbits-backup-${formatIsoDate(now)}.json');
  await file.writeAsString(json);
  await Share.shareXFiles([XFile(file.path)], subject: 'Habbits backup');
}

/// Lets the user pick a file and decodes it. Returns null if cancelled; throws
/// [BackupFormatException] if the file is not a valid backup.
Future<BackupData?> pickAndDecode() async {
  final result = await FilePicker.platform.pickFiles();
  final path = result?.files.single.path;
  if (path == null) return null;
  return decodeBackup(await File(path).readAsString());
}
```

PLUGIN-API NOTE: `share_plus` changed its API across major versions. The line above uses `Share.shareXFiles([...])`. If `flutter analyze` reports that `Share`/`shareXFiles` is undefined, the installed version uses the newer API — replace that one line with:
```dart
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'Habbits backup'));
```
Use whichever compiles cleanly under the resolved `share_plus` version; report which you used. (This `exportAndShare`/`pickAndDecode` code is not unit-tested — only `buildBackup` and the round-trip are — so `flutter analyze` is the gate that it compiles.)

- [ ] **Step 4: Run to verify it passes + analyze**

```bash
flutter test test/services/backup_service_test.dart
flutter analyze
```
Expected: 2 tests PASS; `flutter analyze` "No issues found!" (confirms the plugin calls compile).

- [ ] **Step 5: Commit**

```bash
git add lib/services/backup_service.dart test/services/backup_service_test.dart
git commit -m "feat(services): add backup build/share/pick + round-trip test"
```

---

### Task 5: Settings screen + home entry point

**Files:**
- Create: `lib/ui/settings/settings_screen.dart`
- Modify: `lib/ui/habit_list/habit_list_screen.dart`
- Test: `test/ui/settings_screen_test.dart`

A Settings screen with Export/Import rows; import shows a strict replace-confirmation then applies. A home app-bar icon opens it.

- [ ] **Step 1: Write the failing widget test** — `test/ui/settings_screen_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/database.dart';
import 'package:habbits/domain/backup.dart';
import 'package:habbits/state/habit_providers.dart';
import 'package:habbits/ui/settings/settings_screen.dart';

void main() {
  testWidgets('renders Export and Import rows', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: SettingsScreen()),
    ));
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

    // Drive the confirm-and-apply path directly (bypassing the file picker).
    late BuildContext ctx;
    await tester.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: Consumer(builder: (context, ref, _) {
          ctx = context;
          return ElevatedButton(
            key: const Key('go'),
            onPressed: () => confirmAndImport(context, ref, data),
            child: const Text('go'),
          );
        }),
      ),
    ));

    await tester.tap(find.byKey(const Key('go')));
    await tester.pumpAndSettle();
    expect(find.textContaining('replace'), findsOneWidget); // confirm dialog copy
    await tester.tap(find.byKey(const Key('confirm-import')));
    await tester.pumpAndSettle();

    final rows = await db.habitDao.getHabitsWithDates();
    expect(rows.single.habit.name, 'Imported');
    expect(rows.single.dates, {DateTime(2026, 6, 2)});
    // silence unused-variable lint on ctx
    expect(ctx, isNotNull);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/ui/settings_screen_test.dart
```
Expected: FAIL — `settings_screen.dart`/`confirmAndImport` undefined.

- [ ] **Step 3: Implement `lib/ui/settings/settings_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/backup.dart';
import '../../services/backup_service.dart';
import '../../state/habit_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      key: const Key('settings-screen'),
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            key: const Key('export-data'),
            leading: const Icon(Icons.upload_file),
            title: const Text('Export data'),
            subtitle: const Text('Save all habits and history to a JSON file'),
            onTap: () => _export(context, ref),
          ),
          ListTile(
            key: const Key('import-data'),
            leading: const Icon(Icons.download),
            title: const Text('Import data'),
            subtitle: const Text('Replace all data from a JSON backup'),
            onTap: () => _import(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      await exportAndShare(ref.read(habitDaoProvider));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final BackupData? data;
    try {
      data = await pickAndDecode();
    } on BackupFormatException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    if (data == null || !context.mounted) return; // cancelled
    await confirmAndImport(context, ref, data);
  }
}

/// Shows the replace-confirmation for [data]; on confirm, replaces all data.
/// Public so it can be widget-tested without the file picker.
Future<void> confirmAndImport(
  BuildContext context,
  WidgetRef ref,
  BackupData data,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Replace all data?'),
      content: Text(
        'This will replace all current habits and history with the file’s '
        'contents (${data.habits.length} habits). This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('confirm-import'),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Replace'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await ref.read(habitDaoProvider).importReplace(data.habits);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${data.habits.length} habits')),
      );
    }
  }
}
```

- [ ] **Step 4: Add the home app-bar entry** — in `lib/ui/habit_list/habit_list_screen.dart`, add the import and a settings action. Change the import block to include:

```dart
import '../settings/settings_screen.dart';
```

and replace the `AppBar`:

```dart
      appBar: AppBar(
        title: const Text('Habbits'),
        actions: [
          IconButton(
            key: const Key('open-settings'),
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
```

- [ ] **Step 5: Run the settings test + full suite + analyze**

```bash
flutter test test/ui/settings_screen_test.dart
flutter analyze
flutter test
```
Expected: settings tests PASS; analyze clean; full suite green (the home screen still has its FAB + cards; the new app-bar action doesn't affect existing home tests).

- [ ] **Step 6: Commit**

```bash
git add lib/ui/settings/settings_screen.dart lib/ui/habit_list/habit_list_screen.dart test/ui/settings_screen_test.dart
git commit -m "feat(ui): add Settings screen with export/import and home entry point"
```

---

### Task 6: Final verification

No code changes.

- [ ] **Step 1: Analyze + full suite**

```bash
flutter analyze
flutter test
```
Expected: `No issues found!`; all tests pass (domain backup, dao import/export, services round-trip, settings widget, plus all prior suites).

- [ ] **Step 2: Confirm clean tree + branch**

```bash
git status
git branch --show-current   # expect feat/export-import, NOT detached
git log --oneline -6 | cat
```
Expected: clean tree; on `feat/export-import`; the 5 implementation commits present.

The merged `integration_test/critical_flow_test.dart` is unaffected (home keeps its Checkbox + Streak text; the only home change is an added app-bar settings icon).

---

## Self-review notes

- **Spec coverage:**
  - §1 JSON format (app/version/exportedAt/habits with inline completions, ISO dates, color int, reminderTime, completions YYYY-MM-DD): Task 2 (`encodeBackup`) + round-trip Task 4.
  - §2 export (one-shot read → build → encode → temp file → share sheet): Task 3 (`getHabitsWithDates`), Task 4 (`buildBackup`, `exportAndShare`).
  - §3 import (file picker → strict validate-before-write → confirm → transactional replace → reactive update): Task 2 (`decodeBackup`), Task 3 (`importReplace`), Task 5 (`pickAndDecode` + `confirmAndImport` + dialog).
  - §4 architecture (pure backup.dart, DAO read/write, service glue, settings screen, home entry): Tasks 2–5.
  - §5 testing (domain round-trip + rejects; DAO import/empty; headline export→import round-trip; settings rows + confirm-applies): Tasks 2, 3, 4, 5.
  - §6 out of scope (no CSV/merge/encryption/schema change): honored — none added.
- **Placeholder scan:** none. The one inline correction (Task 3 Step 1's `createdAt: null` placeholder) is explicitly called out with the corrected test to use. The `share_plus` API variance is flagged with both forms and the analyze gate.
- **Type/name consistency:** `BackupData{version, exportedAt, habits}` / `BackupHabit{name,color,reminderTime,sortOrder,createdAt,completions}` defined in Task 2 and used identically in Tasks 3 (`importReplace(List<BackupHabit>)`), 4 (`buildBackup(...)->BackupData`), 5 (`confirmAndImport(...,BackupData)`); `encodeBackup`/`decodeBackup`/`BackupFormatException` (Task 2) used in Tasks 4–5; DAO `getHabitsWithDates()`/`importReplace()` (Task 3) used in Task 4 service + Task 5; widget keys (`export-data`, `import-data`, `confirm-import`, `open-settings`, `settings-screen`) consistent between Task 5 code and its test.
- **Known judgment calls:** `importReplace` deletes completions then habits explicitly (not relying on cascade) for clarity and to be robust regardless of PRAGMA state; `confirmAndImport` is public specifically so the confirm→apply path is widget-testable without the file-picker plugin; the plugin calls in `backup_service` are gated by `flutter analyze` (compile) and verified on-device manually, not unit-tested.

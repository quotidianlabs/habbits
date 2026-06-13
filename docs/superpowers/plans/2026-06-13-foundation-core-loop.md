# Habbits Foundation + Core Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A dogfoodable Flutter app where you can create, rename, and hard-delete habits, check off "today" per habit, see a correct current streak, and have it all persist locally across an app relaunch.

**Architecture:** Flutter + Drift (typed SQLite) for on-device storage, Riverpod (codegen) for state. The load-bearing correctness logic — streak math — lives in a pure-Dart `domain/` layer with no Flutter or Drift imports, so it is unit-tested in isolation. The data layer (`HabitDao`) wraps Drift; Riverpod providers bridge the DAO to the UI; the UI is a single habit-list screen. Nothing is denormalized: streaks are always derived from completion rows.

**Tech Stack:** Flutter (stable, Material 3), Dart; `drift` + `drift_flutter` (SQLite); `flutter_riverpod` + `riverpod_annotation` (+ `riverpod_generator`, `build_runner`, `drift_dev` for codegen); `flutter_test` + `integration_test` (SDK).

**Source spec:** `docs/superpowers/specs/2026-06-13-habbits-mobile-local-first-design.md`. This plan implements the **core loop** slice (spec §3 product rules for *streak / check-off / delete / rename*, §4 data model, §5 architecture, §6 core + current-streak, §8 critical flow). Heatmap + retroactive editing + 30-day % (§6) are a separate Plan 2; reminders Plan 3; export/import Plan 4.

**Scope boundary:** This plan ships the **today-only** check-off via the list screen. Tapping arbitrary past days (retroactive editing) arrives in Plan 2 with the heatmap. The `completions` schema and `toggleCompletion(habitId, date)` DAO method already accept any date, so Plan 2 adds UI only — no migration.

**Pre-flight (developer, not the agent):** Flutter SDK installed and on PATH (`flutter --version` shows a stable channel ≥ 3.24). An iOS Simulator and/or Android emulator available for the integration test (`flutter devices` lists at least one). Working from the `restart/mobile-local-first` branch.

---

### Task 1: Scaffold the Flutter project

**Files:**
- Create: `pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart`, `android/`, `ios/` (all via `flutter create`)
- Delete: `test/widget_test.dart` (generated counter-app test)
- Modify: `.gitignore` (Flutter patterns)

The repo currently contains only `docs/` and `.gitignore`. `flutter create` scaffolds into the existing directory without touching `docs/`.

- [ ] **Step 1: Scaffold into the current directory**

```bash
flutter create --org com.example --project-name habbits --platforms ios,android .
```

Note: `com.example` is a placeholder applicationId/bundleId. Finalize a real reverse-DNS org before any store upload (out of scope for this plan). Expected: creates `lib/`, `test/`, `android/`, `ios/`, `pubspec.yaml`, `analysis_options.yaml`. `docs/` is untouched.

- [ ] **Step 2: Add runtime dependencies**

```bash
flutter pub add drift drift_flutter flutter_riverpod riverpod_annotation
```

Expected: `pubspec.yaml` `dependencies:` now lists all four. Versions resolve to current (`drift` 2.x, `flutter_riverpod` 3.x).

- [ ] **Step 3: Add dev/codegen dependencies**

```bash
flutter pub add dev:build_runner dev:drift_dev dev:riverpod_generator dev:custom_lint dev:riverpod_lint
flutter pub add dev:integration_test --sdk=flutter
```

Expected: `dev_dependencies:` lists `build_runner`, `drift_dev`, `riverpod_generator`, `custom_lint`, `riverpod_lint`, and `integration_test` (from the Flutter SDK).

- [ ] **Step 4: Enable the custom_lint analyzer plugin**

Replace the generated `analysis_options.yaml` with:

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  plugins:
    - custom_lint
  exclude:
    - "**/*.g.dart"

linter:
  rules:
    prefer_const_constructors: true
    prefer_final_locals: true
```

- [ ] **Step 5: Remove the generated counter-app test**

```bash
rm test/widget_test.dart
```

It references the counter scaffold we are about to replace and would fail to compile once `main.dart` changes.

- [ ] **Step 6: Replace `lib/main.dart` with a minimal Riverpod root**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: HabbitsApp()));
}

class HabbitsApp extends StatelessWidget {
  const HabbitsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habbits',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const Scaffold(body: Center(child: Text('Habbits'))),
    );
  }
}
```

- [ ] **Step 7: Append Flutter patterns to `.gitignore`**

Append (the existing `.idea` line stays):

```
# Flutter / Dart
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
build/
*.g.dart.bak
.DS_Store

# Generated code is committed (see plan); do NOT ignore *.g.dart
```

- [ ] **Step 8: Verify it builds and analyzes clean**

```bash
flutter pub get
flutter analyze
```

Expected: `No issues found!` (or only info-level lints).

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: scaffold Flutter project with Drift + Riverpod deps"
```

---

### Task 2: Pure date helpers

**Files:**
- Create: `lib/domain/dates.dart`
- Test: `test/domain/dates_test.dart`

Date-only normalization and calendar-day arithmetic. Using `DateTime(y, m, d)` construction (not `Duration`-based subtraction) is what makes streak math DST-safe: it operates on calendar dates, never on UTC offsets.

- [ ] **Step 1: Write the failing test**

Create `test/domain/dates_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/dates.dart';

void main() {
  test('dateOnly strips the time component', () {
    expect(dateOnly(DateTime(2026, 6, 13, 14, 30, 59)), DateTime(2026, 6, 13));
  });

  test('previousDay rolls back across a month boundary', () {
    expect(previousDay(DateTime(2026, 3, 1)), DateTime(2026, 2, 28));
  });

  test('previousDay rolls back across a year boundary', () {
    expect(previousDay(DateTime(2026, 1, 1)), DateTime(2025, 12, 31));
  });

  test('previousDay is correct across a DST spring-forward date (US 2026-03-08)', () {
    // Calendar-date arithmetic must not lose or gain a day at a DST boundary.
    expect(previousDay(DateTime(2026, 3, 9)), DateTime(2026, 3, 8));
    expect(previousDay(DateTime(2026, 3, 8)), DateTime(2026, 3, 7));
  });

  test('formatIsoDate and parseIsoDate round-trip', () {
    final d = DateTime(2026, 6, 13);
    expect(formatIsoDate(d), '2026-06-13');
    expect(parseIsoDate('2026-06-13'), d);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/domain/dates_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: 'package:habbits/domain/dates.dart'`.

- [ ] **Step 3: Implement `lib/domain/dates.dart`**

```dart
/// Pure calendar-date helpers. No Flutter, no Drift imports.

/// Strips the time-of-day, returning a date at local midnight.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The calendar day before [d]. Uses date construction (not Duration) so it is
/// correct across month, year, and DST boundaries.
DateTime previousDay(DateTime d) => DateTime(d.year, d.month, d.day - 1);

/// Formats a date as `YYYY-MM-DD` for storage.
String formatIsoDate(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-$m-$day';
}

/// Parses a `YYYY-MM-DD` string into a date-only [DateTime].
DateTime parseIsoDate(String s) {
  final parts = s.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/domain/dates_test.dart
```

Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/dates.dart test/domain/dates_test.dart
git commit -m "feat(domain): add pure calendar-date helpers"
```

---

### Task 3: Streak domain logic

**Files:**
- Create: `lib/domain/streak.dart`
- Test: `test/domain/streak_test.dart`

The most important correctness surface in the app. Pure function over a set of completed dates. Per spec §3: the streak ends at today if today is completed, otherwise at yesterday (today not yet checked but the run is still alive); a gap resets it to 0.

- [ ] **Step 1: Write the failing table-driven test**

Create `test/domain/streak_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/dates.dart';
import 'package:habbits/domain/streak.dart';

void main() {
  final today = DateTime(2026, 6, 13);
  Set<DateTime> daysBack(List<int> offsets) =>
      offsets.map((o) => DateTime(2026, 6, 13 - o)).toSet();

  final cases = <String, ({Set<DateTime> completed, int expected})>{
    'empty set is 0': (completed: <DateTime>{}, expected: 0),
    'only today is 1': (completed: daysBack([0]), expected: 1),
    'today + yesterday is 2': (completed: daysBack([0, 1]), expected: 2),
    'yesterday only (today unchecked) keeps streak alive at 1':
        (completed: daysBack([1]), expected: 1),
    'two days ago only (yesterday missing) is 0':
        (completed: daysBack([2]), expected: 0),
    'today + yesterday, gap at 2 days ago is 2':
        (completed: daysBack([0, 1, 3]), expected: 2),
    'ten-day run is 10': (completed: daysBack([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]), expected: 10),
  };

  cases.forEach((name, c) {
    test(name, () {
      expect(currentStreak(c.completed, today), c.expected);
    });
  });

  test('counts correctly across a month boundary', () {
    final march1 = DateTime(2026, 3, 1);
    final completed = {
      DateTime(2026, 3, 1),
      DateTime(2026, 2, 28),
      DateTime(2026, 2, 27),
    };
    expect(currentStreak(completed, march1), 3);
  });

  test('normalizes inputs that carry a time component', () {
    final completed = {DateTime(2026, 6, 13, 9, 0), DateTime(2026, 6, 12, 23, 59)};
    expect(currentStreak(completed, DateTime(2026, 6, 13, 14, 0)), 2);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/domain/streak_test.dart
```

Expected: FAIL — `streak.dart` does not exist.

- [ ] **Step 3: Implement `lib/domain/streak.dart`**

```dart
import 'dates.dart';

/// Current consecutive-day streak per spec §3.
///
/// The streak ends at today if today is completed; otherwise at yesterday (the
/// run is still alive until the day actually lapses). A gap resets it to 0.
/// [completed] may contain times; they are normalized to date-only.
int currentStreak(Set<DateTime> completed, DateTime today) {
  final days = completed.map(dateOnly).toSet();
  final t = dateOnly(today);

  DateTime anchor;
  if (days.contains(t)) {
    anchor = t;
  } else if (days.contains(previousDay(t))) {
    anchor = previousDay(t);
  } else {
    return 0;
  }

  var streak = 0;
  var cursor = anchor;
  while (days.contains(cursor)) {
    streak++;
    cursor = previousDay(cursor);
  }
  return streak;
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/domain/streak_test.dart
```

Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/streak.dart test/domain/streak_test.dart
git commit -m "feat(domain): add current-streak computation with DST-safe table tests"
```

---

### Task 4: Drift database schema

**Files:**
- Create: `lib/data/database.dart`
- Create (generated): `lib/data/database.g.dart` (via build_runner)
- Test: `test/data/database_test.dart`

Two tables per spec §4 (`habits`, `completions`), foreign-key cascade on delete, and a composite unique key on `(habit_id, local_date)`. `PRAGMA foreign_keys = ON` is set in `beforeOpen` so the cascade actually fires (SQLite defaults it off).

- [ ] **Step 1: Write `lib/data/database.dart` (schema + connection)**

```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'habit_dao.dart';

part 'database.g.dart';

class Habits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get color => integer()();
  TextColumn get reminderTime => text().nullable()(); // 'HH:mm', null = none
  IntColumn get sortOrder => integer()();
  DateTimeColumn get createdAt => dateTime()();
}

class Completions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get habitId =>
      integer().references(Habits, #id, onDelete: KeyAction.cascade)();
  TextColumn get localDate => text()(); // 'YYYY-MM-DD'
  DateTimeColumn get createdAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {habitId, localDate},
      ];
}

@DriftDatabase(tables: [Habits, Completions], daos: [HabitDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'habbits'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
```

Note: `habit_dao.dart` (Task 5) is imported here because `daos:` references `HabitDao`. The build in Step 3 will fail until that file exists, so **create the `HabitDao` file stub now**:

Create `lib/data/habit_dao.dart` with a minimal stub (full implementation in Task 5):

```dart
import 'package:drift/drift.dart';

import 'database.dart';

part 'habit_dao.g.dart';

@DriftAccessor(tables: [Habits, Completions])
class HabitDao extends DatabaseAccessor<AppDatabase> with _$HabitDaoMixin {
  HabitDao(super.db);
}
```

- [ ] **Step 2: Write the failing database test**

Create `test/data/database_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('inserts and reads a habit', () async {
    final id = await db.into(db.habits).insert(HabitsCompanion.insert(
          name: 'Medicine',
          color: 0xFF009688,
          sortOrder: 0,
          createdAt: DateTime(2026, 6, 13),
        ));
    final row = await (db.select(db.habits)..where((h) => h.id.equals(id))).getSingle();
    expect(row.name, 'Medicine');
  });

  test('rejects a duplicate (habitId, localDate)', () async {
    final habitId = await db.into(db.habits).insert(HabitsCompanion.insert(
          name: 'Read', color: 1, sortOrder: 0, createdAt: DateTime(2026, 6, 13)));
    await db.into(db.completions).insert(CompletionsCompanion.insert(
          habitId: habitId, localDate: '2026-06-13', createdAt: DateTime(2026, 6, 13)));

    expect(
      () => db.into(db.completions).insert(CompletionsCompanion.insert(
            habitId: habitId, localDate: '2026-06-13', createdAt: DateTime(2026, 6, 13))),
      throwsA(isA<Exception>()),
    );
  });

  test('deleting a habit cascades to its completions', () async {
    final habitId = await db.into(db.habits).insert(HabitsCompanion.insert(
          name: 'Workout', color: 1, sortOrder: 0, createdAt: DateTime(2026, 6, 13)));
    await db.into(db.completions).insert(CompletionsCompanion.insert(
          habitId: habitId, localDate: '2026-06-13', createdAt: DateTime(2026, 6, 13)));

    await (db.delete(db.habits)..where((h) => h.id.equals(habitId))).go();

    final remaining = await db.select(db.completions).get();
    expect(remaining, isEmpty);
  });
}
```

- [ ] **Step 3: Generate the Drift code**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: creates `lib/data/database.g.dart` and `lib/data/habit_dao.g.dart`. No errors.

- [ ] **Step 4: Run the database test**

```bash
flutter test test/data/database_test.dart
```

Expected: PASS (3 tests). If the cascade test fails with completions remaining, confirm `PRAGMA foreign_keys = ON` is in `beforeOpen`.

- [ ] **Step 5: Commit (including generated code)**

```bash
git add lib/data/database.dart lib/data/habit_dao.dart lib/data/database.g.dart lib/data/habit_dao.g.dart test/data/database_test.dart
git commit -m "feat(data): add Drift schema with FK cascade and unique check-off constraint"
```

---

### Task 5: HabitDao — CRUD, toggle, and the reactive list query

**Files:**
- Modify: `lib/data/habit_dao.dart`
- Modify (generated): `lib/data/habit_dao.g.dart`
- Test: `test/data/habit_dao_test.dart`

The DAO owns all reads/writes. `watchHabitsWithDates()` is a single reactive query (left join) that emits whenever either table changes, returning each habit with the set of dates it was completed on — exactly what the streak function needs.

- [ ] **Step 1: Write the failing DAO test**

Create `test/data/habit_dao_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/database.dart';
import 'package:habbits/data/habit_dao.dart';

void main() {
  late AppDatabase db;
  late HabitDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.habitDao;
  });
  tearDown(() => db.close());

  test('createHabit assigns incrementing sort order', () async {
    final a = await dao.createHabit(name: 'A', color: 1);
    final b = await dao.createHabit(name: 'B', color: 2);
    final rows = await dao.watchHabitsWithDates().first;
    expect(rows.map((r) => r.habit.id), [a, b]);
    expect(rows.map((r) => r.habit.sortOrder), [0, 1]);
  });

  test('renameHabit changes the name', () async {
    final id = await dao.createHabit(name: 'Old', color: 1);
    await dao.renameHabit(id, 'New');
    final rows = await dao.watchHabitsWithDates().first;
    expect(rows.single.habit.name, 'New');
  });

  test('toggleCompletion is idempotent: on then off nets to empty', () async {
    final id = await dao.createHabit(name: 'Read', color: 1);
    final date = DateTime(2026, 6, 13);

    await dao.toggleCompletion(id, date);
    var rows = await dao.watchHabitsWithDates().first;
    expect(rows.single.dates, {DateTime(2026, 6, 13)});

    await dao.toggleCompletion(id, date);
    rows = await dao.watchHabitsWithDates().first;
    expect(rows.single.dates, isEmpty);
  });

  test('watchHabitsWithDates groups completion dates per habit', () async {
    final id = await dao.createHabit(name: 'Meditate', color: 1);
    await dao.toggleCompletion(id, DateTime(2026, 6, 13));
    await dao.toggleCompletion(id, DateTime(2026, 6, 12));

    final rows = await dao.watchHabitsWithDates().first;
    expect(rows.single.dates, {DateTime(2026, 6, 13), DateTime(2026, 6, 12)});
  });

  test('deleteHabit removes the habit and its completions', () async {
    final id = await dao.createHabit(name: 'Gone', color: 1);
    await dao.toggleCompletion(id, DateTime(2026, 6, 13));

    await dao.deleteHabit(id);

    final rows = await dao.watchHabitsWithDates().first;
    expect(rows, isEmpty);
    final completions = await db.select(db.completions).get();
    expect(completions, isEmpty);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/data/habit_dao_test.dart
```

Expected: FAIL — `createHabit`, `watchHabitsWithDates`, etc. are undefined on the stub DAO.

- [ ] **Step 3: Implement the full `lib/data/habit_dao.dart`**

```dart
import 'package:drift/drift.dart';

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

  /// Reactive stream of every habit with its completion dates, ordered by
  /// sortOrder. Emits on any change to either table.
  Stream<List<HabitWithDates>> watchHabitsWithDates() {
    final query = select(habits).join([
      leftOuterJoin(completions, completions.habitId.equalsExp(habits.id)),
    ])
      ..orderBy([OrderingTerm(expression: habits.sortOrder)]);

    return query.watch().map((rows) {
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
    });
  }
}
```

- [ ] **Step 4: Regenerate code and run the test**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/data/habit_dao_test.dart
```

Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/habit_dao.dart lib/data/habit_dao.g.dart test/data/habit_dao_test.dart
git commit -m "feat(data): implement HabitDao CRUD, idempotent toggle, reactive list query"
```

---

### Task 6: Riverpod providers + list view-model

**Files:**
- Create: `lib/state/habit_providers.dart`
- Create (generated): `lib/state/habit_providers.g.dart`
- Test: `test/state/habit_providers_test.dart`

Providers bridge the DAO to the UI. `HabitSummary` is the per-row view-model (habit + computed streak + whether today is done). The streak is computed here by feeding the DAO's date set into the pure `currentStreak` function.

- [ ] **Step 1: Write `lib/state/habit_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/database.dart';
import '../data/habit_dao.dart';
import '../domain/dates.dart';
import '../domain/streak.dart';

part 'habit_providers.g.dart';

/// View-model for one row in the habit list.
class HabitSummary {
  HabitSummary({required this.habit, required this.streak, required this.doneToday});
  final Habit habit;
  final int streak;
  final bool doneToday;
}

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

@riverpod
HabitDao habitDao(Ref ref) => ref.watch(appDatabaseProvider).habitDao;

@riverpod
Stream<List<HabitSummary>> habitSummaries(Ref ref) {
  final dao = ref.watch(habitDaoProvider);
  return dao.watchHabitsWithDates().map((rows) {
    final today = dateOnly(DateTime.now());
    return [
      for (final row in rows)
        HabitSummary(
          habit: row.habit,
          streak: currentStreak(row.dates, today),
          doneToday: row.dates.contains(today),
        ),
    ];
  });
}
```

- [ ] **Step 2: Write the failing provider test**

Create `test/state/habit_providers_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/database.dart';
import 'package:habbits/domain/dates.dart';
import 'package:habbits/state/habit_providers.dart';

void main() {
  test('habitSummaries computes streak and doneToday for today check-off', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    final id = await container.read(habitDaoProvider).createHabit(name: 'Read', color: 1);
    await container.read(habitDaoProvider).toggleCompletion(id, dateOnly(DateTime.now()));

    final summaries = await container.read(habitSummariesProvider.future);
    expect(summaries.single.habit.name, 'Read');
    expect(summaries.single.streak, 1);
    expect(summaries.single.doneToday, isTrue);
  });
}
```

- [ ] **Step 3: Generate code and run the test (verify it fails first if generation is skipped)**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/state/habit_providers_test.dart
```

Expected: PASS (1 test). (If you run the test *before* generating, it fails to compile on the missing `*.g.dart` — generate, then it passes.)

- [ ] **Step 4: Commit**

```bash
git add lib/state/habit_providers.dart lib/state/habit_providers.g.dart test/state/habit_providers_test.dart
git commit -m "feat(state): add Riverpod providers and habit-summary view-model"
```

---

### Task 7: Habit list screen (add / check off / rename / delete)

**Files:**
- Create: `lib/ui/habit_list/habit_list_screen.dart`
- Test: `test/ui/habit_list_screen_test.dart`

The single MVP screen: a list of habits each showing name, current streak, and a check-off control for today; a FAB to add; long-press (or trailing menu) to rename or hard-delete. Delete shows a confirmation per spec §3 ("permanent").

- [ ] **Step 1: Write the failing widget test**

Create `test/ui/habit_list_screen_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/database.dart';
import 'package:habbits/state/habit_providers.dart';
import 'package:habbits/ui/habit_list/habit_list_screen.dart';

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
  });

  testWidgets('checking off today bumps the streak to 1', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.habitDao.createHabit(name: 'Read', color: 0xFF009688);
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('checkoff-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Streak: 1'), findsOneWidget);
  });

  testWidgets('deleting a habit requires confirmation then removes it', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.habitDao.createHabit(name: 'Workout', color: 0xFF009688);
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('habit-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    // Confirmation dialog
    expect(find.textContaining('permanent'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();

    expect(find.text('Workout'), findsNothing);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/ui/habit_list_screen_test.dart
```

Expected: FAIL — `habit_list_screen.dart` does not exist.

- [ ] **Step 3: Implement `lib/ui/habit_list/habit_list_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dates.dart';
import '../../state/habit_providers.dart';

class HabitListScreen extends ConsumerWidget {
  const HabitListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(habitSummariesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Habbits')),
      floatingActionButton: FloatingActionButton(
        key: const Key('add-habit-fab'),
        onPressed: () => _showNameDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: summaries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No habits yet. Tap + to add one.'));
          }
          return ListView(
            children: [for (final item in items) _HabitTile(item: item)],
          );
        },
      ),
    );
  }
}

class _HabitTile extends ConsumerWidget {
  const _HabitTile({required this.item});
  final HabitSummary item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dao = ref.read(habitDaoProvider);
    return ListTile(
      leading: Checkbox(
        key: const Key('checkoff-toggle'),
        value: item.doneToday,
        onChanged: (_) => dao.toggleCompletion(item.habit.id, dateOnly(DateTime.now())),
      ),
      title: Text(item.habit.name),
      subtitle: Text('Streak: ${item.streak}'),
      trailing: PopupMenuButton<String>(
        key: const Key('habit-menu'),
        onSelected: (value) {
          if (value == 'rename') {
            _showNameDialog(context, ref, habitId: item.habit.id, initial: item.habit.name);
          } else if (value == 'delete') {
            _confirmDelete(context, ref, item.habit.id, item.habit.name);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'rename', child: Text('Rename')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}

Future<void> _showNameDialog(
  BuildContext context,
  WidgetRef ref, {
  int? habitId,
  String? initial,
}) async {
  final controller = TextEditingController(text: initial ?? '');
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(habitId == null ? 'New habit' : 'Rename habit'),
      content: TextField(
        key: const Key('habit-name-field'),
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('habit-name-confirm'),
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (name == null || name.isEmpty) return;
  final dao = ref.read(habitDaoProvider);
  if (habitId == null) {
    await dao.createHabit(name: name, color: Colors.teal.toARGB32());
  } else {
    await dao.renameHabit(habitId, name);
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  int habitId,
  String name,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete "$name"?'),
      content: const Text(
        'This permanently deletes the habit and all its check-off history. '
        'This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('confirm-delete'),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(habitDaoProvider).deleteHabit(habitId);
  }
}
```

Note: `Colors.teal.toARGB32()` returns the ARGB int for storage (Flutter's current API; replaces the deprecated `.value`). If your Flutter version predates `toARGB32()`, use `Colors.teal.value`.

- [ ] **Step 4: Run the widget test**

```bash
flutter test test/ui/habit_list_screen_test.dart
```

Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/habit_list/habit_list_screen.dart test/ui/habit_list_screen_test.dart
git commit -m "feat(ui): habit list screen with add, check-off, rename, delete-with-confirm"
```

---

### Task 8: Wire the app entry point

**Files:**
- Modify: `lib/main.dart`

Point the app's home at the real screen.

- [ ] **Step 1: Replace `lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/habit_list/habit_list_screen.dart';

void main() {
  runApp(const ProviderScope(child: HabbitsApp()));
}

class HabbitsApp extends StatelessWidget {
  const HabbitsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habbits',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const HabitListScreen(),
    );
  }
}
```

- [ ] **Step 2: Analyze and run the full unit/widget suite**

```bash
flutter analyze
flutter test
```

Expected: `No issues found!` and all tests green (dates, streak, database, dao, providers, ui).

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: wire app entry point to habit list screen"
```

---

### Task 9: Critical-flow integration test (with relaunch persistence)

**Files:**
- Create: `integration_test/critical_flow_test.dart`

Per spec §8: open → create habit → check off today → streak = 1 → relaunch → state persists. Process relaunch is simulated by tearing down the widget tree and pumping a fresh `ProviderScope` over the **same file-backed database**, which is what a real relaunch reopens.

- [ ] **Step 1: Write the integration test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:habbits/data/database.dart';
import 'package:habbits/state/habit_providers.dart';
import 'package:habbits/ui/habit_list/habit_list_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Widget appWith(AppDatabase db) => ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HabitListScreen()),
      );

  testWidgets('create, check off, streak=1, persists across relaunch', (tester) async {
    // A single file-backed database, shared across two "launches".
    final db = AppDatabase();
    // Start clean in case a prior run left data.
    await db.delete(db.habits).go();

    // --- Launch 1 ---
    await tester.pumpWidget(appWith(db));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-habit-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('habit-name-field')), 'Medicine');
    await tester.tap(find.byKey(const Key('habit-name-confirm')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('checkoff-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Medicine'), findsOneWidget);
    expect(find.text('Streak: 1'), findsOneWidget);
    await db.close();

    // --- Launch 2 (relaunch): reopen the same on-disk database ---
    final reopened = AppDatabase();
    addTearDown(reopened.close);
    await tester.pumpWidget(appWith(reopened));
    await tester.pumpAndSettle();

    expect(find.text('Medicine'), findsOneWidget);
    expect(find.text('Streak: 1'), findsOneWidget);

    // Cleanup so reruns stay deterministic.
    await reopened.delete(reopened.habits).go();
  });
}
```

- [ ] **Step 2: Run the integration test on a device/emulator**

```bash
flutter test integration_test/critical_flow_test.dart
```

Expected: PASS. Requires a running simulator/emulator (`flutter devices` shows one). If multiple devices, add `-d <device-id>`.

- [ ] **Step 3: Commit**

```bash
git add integration_test/critical_flow_test.dart
git commit -m "test: add critical-flow integration test with relaunch persistence"
```

---

### Task 10: Final verification + README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write `README.md`**

```markdown
# Habbits

A local-first, cross-platform habit tracker. Your data lives on your device —
no account, no server, no paywall. Habits are fully editable and hard-deletable
("okay, gone"), and exportable. Open source.

## Status

MVP in progress. This slice ships the core loop: create / rename / delete habits,
check off today, and see your current streak — all persisted locally via SQLite.

## Stack

Flutter · Drift (SQLite) · Riverpod. Pure-Dart domain layer for streak logic.

## Develop

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # after schema/provider changes
flutter test            # unit + widget tests
flutter run             # on a simulator/emulator
```

See `docs/superpowers/specs/2026-06-13-habbits-mobile-local-first-design.md` for the design.
```

- [ ] **Step 2: Run the complete suite one final time**

```bash
flutter analyze
flutter test
```

Expected: clean analyze; all unit/widget tests pass.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add README"
```

---

## Self-review notes

- **Spec coverage:**
  - §2 stack (Flutter, Drift, Riverpod, codegen): Task 1.
  - §3 streak rule (ends today-or-yesterday, gap resets, forgiving/no-punishment): Task 3 (logic + tests); no punitive UI added anywhere (Task 7 shows only "Streak: N").
  - §3 idempotent check-off: Task 5 `toggleCompletion` + test.
  - §3 hard delete with confirmation: Task 5 (`deleteHabit` + cascade) + Task 7 (confirm dialog with "permanent" copy).
  - §3 rename: Task 5 + Task 7.
  - §4 data model (two tables, FK cascade, unique key): Task 4.
  - §5 architecture (pure domain, data, state, ui layers): Tasks 2–8 follow the directory map.
  - §6 core + current streak: Tasks 3, 5, 6, 7. (Heatmap, retroactive editing, 30-day % are explicitly Plan 2.)
  - §7 correctness/idempotency/cascade quality bars: Tasks 3, 4, 5 tests.
  - §8 critical flow incl. relaunch persistence: Task 9.
- **Out-of-slice (deferred, not gaps):** heatmap, retroactive editing, 30-day % (Plan 2); reminders (Plan 3); export/import (Plan 4); home-screen widget (Plan 5). The `reminderTime` column exists now (Task 4) so reminders need no migration.
- **Placeholder scan:** none. `com.example` org and the `toARGB32()`/`.value` fallback are explicitly flagged inline, not left ambiguous.
- **Type/name consistency:** `AppDatabase([QueryExecutor?])` used identically in every test and provider; `HabitDao` methods (`createHabit`, `renameHabit`, `deleteHabit`, `toggleCompletion`, `watchHabitsWithDates`) match across Tasks 5–9; `HabitWithDates(habit, dates)` (Task 5) feeds `HabitSummary(habit, streak, doneToday)` (Task 6) feeds the UI (Task 7); `currentStreak(Set<DateTime>, DateTime)` signature is identical in Tasks 3 and 6; widget `Key`s (`add-habit-fab`, `habit-name-field`, `habit-name-confirm`, `checkoff-toggle`, `habit-menu`, `confirm-delete`) match between Task 7 and Task 9.
- **Codegen discipline:** generated `*.g.dart` are committed (Tasks 4, 5, 6) and `*.g.dart` is excluded from analysis but NOT gitignored (Task 1).

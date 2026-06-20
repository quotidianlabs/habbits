---
status: shipped
date: 2026-06-13
slug: heatmap-retroactive-editing
spec: heatmap-retroactive-editing
pr: merged to main locally
---

# Heatmap + Retroactive Editing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a per-habit GitHub-style heatmap (read-only mini on each home card; full, scrollable, tap-any-day editable on a new detail screen), retroactive check-off editing, and the 30-day completion %.

**Architecture:** Two new pure-Dart domain functions (`completion_stats`, `heatmap`) plus two date helpers, a single reusable heatmap widget used at two sizes/interactivities, a new habit-detail screen, and a restructured home card. State flows through the existing reactive `watchHabitsWithDates()` stream — `HabitSummary` gains `dates` + `completionPercent`, and a derived `habitDetailProvider(id)` feeds the detail screen so edits update everywhere. No schema change; `HabitDao.toggleCompletion(habitId, date)` already accepts any date.

**Tech Stack:** Flutter (Material 3), Drift, Riverpod (codegen). Pure-Dart domain layer for all date/stat/grid logic.

**Source spec:** `docs/superpowers/specs/2026-06-13-heatmap-retroactive-editing-design.md`. Foundation: `docs/superpowers/specs/2026-06-13-habbits-mobile-local-first-design.md`.

**Pre-flight:** Flutter on PATH (`/opt/homebrew/bin`). Working on branch `feat/heatmap-retroactive`. Run `export PATH="/opt/homebrew/bin:$PATH"` if `flutter` is not found. Generated `*.g.dart` files are committed in this repo — regenerate with `dart run build_runner build --delete-conflicting-outputs` after touching `@riverpod`/Drift annotations.

**Existing interfaces you will use (do not re-implement):**
- `lib/domain/dates.dart`: `dateOnly(DateTime)`, `previousDay(DateTime)`, `formatIsoDate(DateTime)`, `parseIsoDate(String)`.
- `lib/domain/streak.dart`: `int currentStreak(Set<DateTime> completed, DateTime today)`.
- `lib/data/habit_dao.dart`: `HabitDao` with `createHabit({name,color})`, `renameHabit(id,name)`, `deleteHabit(id)`, `toggleCompletion(habitId, DateTime date)` (any date), `watchHabitsWithDates()` → `Stream<List<HabitWithDates>>` where `HabitWithDates` has `.habit` (a Drift `Habit` row with `.id`, `.name`, `.color` (int ARGB), `.createdAt` (DateTime)) and `.dates` (`Set<DateTime>`).
- `lib/state/habit_providers.dart`: `appDatabaseProvider`, `habitDaoProvider`, `habitSummariesProvider`, `HabitSummary`.

---

### Task 1: Date helpers — `daysBetween` and `mondayOf`

**Files:**
- Modify: `lib/domain/dates.dart`
- Test: `test/domain/dates_test.dart`

Two DST-safe calendar helpers needed by the stats and heatmap functions: a robust day-count between two dates, and the Monday that starts a date's week (weeks start Monday per spec).

- [ ] **Step 1: Add failing tests** to the existing `test/domain/dates_test.dart` (append inside the existing `main()`):

```dart
  test('daysBetween counts whole calendar days, DST-safe', () {
    expect(daysBetween(DateTime(2026, 6, 13), DateTime(2026, 6, 13)), 0);
    expect(daysBetween(DateTime(2026, 6, 13), DateTime(2026, 6, 14)), 1);
    expect(daysBetween(DateTime(2026, 3, 1), DateTime(2026, 3, 31)), 30);
    // Spans the US spring-forward (2026-03-08); must still be 7 calendar days.
    expect(daysBetween(DateTime(2026, 3, 5), DateTime(2026, 3, 12)), 7);
    // Negative when 'to' precedes 'from'.
    expect(daysBetween(DateTime(2026, 6, 14), DateTime(2026, 6, 13)), -1);
  });

  test('mondayOf returns the Monday of the week containing the date', () {
    // 2026-06-13 is a Saturday.
    expect(mondayOf(DateTime(2026, 6, 13)), DateTime(2026, 6, 8));
    // A Monday maps to itself.
    expect(mondayOf(DateTime(2026, 6, 8)), DateTime(2026, 6, 8));
    // A Sunday maps to the Monday 6 days earlier.
    expect(mondayOf(DateTime(2026, 6, 14)), DateTime(2026, 6, 8));
  });
```

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/domain/dates_test.dart
```
Expected: FAIL — `daysBetween` and `mondayOf` are undefined.

- [ ] **Step 3: Append to `lib/domain/dates.dart`** (after the existing functions):

```dart
/// Number of whole calendar days from [from] to [to] (date-only). Negative if
/// [to] precedes [from]. Divides hours by 24 and rounds so a single DST
/// transition inside the span does not shift the count.
int daysBetween(DateTime from, DateTime to) {
  final f = DateTime(from.year, from.month, from.day);
  final t = DateTime(to.year, to.month, to.day);
  return (t.difference(f).inHours / 24).round();
}

/// The Monday of the week containing [d] (weeks start Monday). DST-safe via
/// calendar-date construction.
DateTime mondayOf(DateTime d) {
  final date = DateTime(d.year, d.month, d.day);
  return DateTime(date.year, date.month, date.day - (date.weekday - 1));
}
```

- [ ] **Step 4: Run to verify pass**

```bash
flutter test test/domain/dates_test.dart
```
Expected: PASS (existing tests + 2 new).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/dates.dart test/domain/dates_test.dart
git commit -m "feat(domain): add daysBetween and mondayOf calendar helpers"
```

---

### Task 2: 30-day completion percentage

**Files:**
- Create: `lib/domain/completion_stats.dart`
- Test: `test/domain/completion_stats_test.dart`

Pure function implementing spec §3: `completed ÷ min(30, days since creation)`, excluding today when unchecked; `null` when there is no eligible window yet.

- [ ] **Step 1: Write the failing test** — create `test/domain/completion_stats_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/completion_stats.dart';

void main() {
  final today = DateTime(2026, 6, 13);
  DateTime daysAgo(int n) => DateTime(2026, 6, 13 - n);

  test('created today, nothing checked -> null (no eligible window)', () {
    expect(completionPercent(<DateTime>{}, today, today), isNull);
  });

  test('created today, checked today -> 100', () {
    expect(completionPercent({daysAgo(0)}, today, today), 100);
  });

  test('today unchecked is excluded from the window', () {
    // Created 2 days ago; checked the two prior days but not today.
    // Window ends yesterday, size = 2, completed = 2 -> 100.
    final created = daysAgo(2);
    expect(completionPercent({daysAgo(1), daysAgo(2)}, created, today), 100);
  });

  test('partial window under 30 days', () {
    // Created 4 days ago, checked 3 of the 5 days incl today -> 3/5 = 60.
    final created = daysAgo(4);
    final done = {daysAgo(0), daysAgo(1), daysAgo(3)};
    expect(completionPercent(done, created, today), 60);
  });

  test('window caps at 30 days for old habits', () {
    // Created 100 days ago; completed exactly the 15 most recent days incl today.
    final created = daysAgo(100);
    final done = {for (var i = 0; i < 15; i++) daysAgo(i)};
    expect(completionPercent(done, created, today), 50); // 15 / 30
  });

  test('rounds to nearest integer percent', () {
    // Created 2 days ago, checked today only, window = 3 (today checked) -> 1/3 = 33.
    final created = daysAgo(2);
    expect(completionPercent({daysAgo(0)}, created, today), 33);
  });
}
```

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/domain/completion_stats_test.dart
```
Expected: FAIL — file/function undefined.

- [ ] **Step 3: Implement `lib/domain/completion_stats.dart`**

```dart
import 'dates.dart';

/// 30-day completion percentage per the foundation spec §3.
///
/// `completed days ÷ min(30, days since creation)`, excluding today when it is
/// not yet checked. Returns `null` when there is no eligible window yet (e.g.
/// the habit was created today and today is not checked) — the UI renders that
/// as "—". All inputs are normalized to date-only.
int? completionPercent(Set<DateTime> completed, DateTime createdAt, DateTime today) {
  final days = completed.map(dateOnly).toSet();
  final created = dateOnly(createdAt);
  final t = dateOnly(today);

  // Today is excluded from the window until it is checked.
  final lastDay = days.contains(t) ? t : previousDay(t);

  final spanDays = daysBetween(created, lastDay) + 1;
  if (spanDays <= 0) return null;

  final windowDays = spanDays < 30 ? spanDays : 30;
  final windowStart =
      DateTime(lastDay.year, lastDay.month, lastDay.day - (windowDays - 1));

  var count = 0;
  for (final d in days) {
    if (!d.isBefore(windowStart) && !d.isAfter(lastDay)) count++;
  }
  return ((count / windowDays) * 100).round();
}
```

- [ ] **Step 4: Run to verify pass**

```bash
flutter test test/domain/completion_stats_test.dart
```
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/completion_stats.dart test/domain/completion_stats_test.dart
git commit -m "feat(domain): add 30-day completion percentage"
```

---

### Task 3: Heatmap grid model

**Files:**
- Create: `lib/domain/heatmap.dart`
- Test: `test/domain/heatmap_test.dart`

Pure function turning completion dates + creation date + today into a grid of weeks (columns) × 7 weekdays (rows, Mon→Sun), each cell classified.

- [ ] **Step 1: Write the failing test** — create `test/domain/heatmap_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/heatmap.dart';

void main() {
  // 2026-06-13 is a Saturday; its week's Monday is 2026-06-08.
  final today = DateTime(2026, 6, 13);

  test('single-week grid classifies each cell', () {
    // Created Wednesday 2026-06-10; completed Thursday 2026-06-11.
    final data = buildHeatmap(
      completed: {DateTime(2026, 6, 11)},
      createdAt: DateTime(2026, 6, 10),
      today: today,
    );
    expect(data.weeks.length, 1);
    final week = data.weeks.single; // Mon..Sun = Jun 8..14
    expect(week[0].state, CellState.beforeCreation); // Mon Jun 8
    expect(week[1].state, CellState.beforeCreation); // Tue Jun 9
    expect(week[2].state, CellState.notCompleted);   // Wed Jun 10 (created)
    expect(week[3].state, CellState.completed);       // Thu Jun 11 (done)
    expect(week[4].state, CellState.notCompleted);   // Fri Jun 12
    expect(week[5].state, CellState.notCompleted);   // Sat Jun 13 (today)
    expect(week[6].state, CellState.future);          // Sun Jun 14
  });

  test('rows are Monday..Sunday and dates line up', () {
    final data = buildHeatmap(
      completed: const {},
      createdAt: DateTime(2026, 6, 8),
      today: today,
    );
    final week = data.weeks.single;
    expect(week[0].date, DateTime(2026, 6, 8)); // Monday
    expect(week[6].date, DateTime(2026, 6, 14)); // Sunday
  });

  test('full history spans from the creation week to today week', () {
    // Created 2026-05-25 (a Monday) -> 3 week-columns through 2026-06-08 week.
    final data = buildHeatmap(
      completed: const {},
      createdAt: DateTime(2026, 5, 25),
      today: today,
    );
    expect(data.weeks.length, 3);
  });

  test('maxWeeks keeps only the most recent N week-columns', () {
    final data = buildHeatmap(
      completed: const {},
      createdAt: DateTime(2026, 5, 25), // would be 3 weeks
      today: today,
      maxWeeks: 2,
    );
    expect(data.weeks.length, 2);
    // The kept columns are the most recent ones; last column is today's week.
    expect(data.weeks.last[5].date, DateTime(2026, 6, 13));
  });
}
```

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/domain/heatmap_test.dart
```
Expected: FAIL — undefined symbols.

- [ ] **Step 3: Implement `lib/domain/heatmap.dart`**

```dart
import 'dates.dart';

/// Classification of one heatmap cell.
enum CellState { completed, notCompleted, future, beforeCreation }

class HeatmapCell {
  const HeatmapCell(this.date, this.state);
  final DateTime date;
  final CellState state;
}

/// A heatmap: a list of week-columns, each a list of exactly 7 cells ordered
/// Monday..Sunday.
class HeatmapData {
  const HeatmapData(this.weeks);
  final List<List<HeatmapCell>> weeks;
}

/// Builds the grid from [completed] dates, the habit's [createdAt], and [today].
/// When [maxWeeks] is non-null, only the most recent [maxWeeks] week-columns are
/// returned (used by the compact home card); null returns full history from the
/// creation week.
HeatmapData buildHeatmap({
  required Set<DateTime> completed,
  required DateTime createdAt,
  required DateTime today,
  int? maxWeeks,
}) {
  final days = completed.map(dateOnly).toSet();
  final created = dateOnly(createdAt);
  final t = dateOnly(today);

  final lastMonday = mondayOf(t);
  var firstMonday = mondayOf(created);
  if (maxWeeks != null) {
    final byMax = DateTime(
        lastMonday.year, lastMonday.month, lastMonday.day - 7 * (maxWeeks - 1));
    if (byMax.isAfter(firstMonday)) firstMonday = byMax;
  }

  final weeks = <List<HeatmapCell>>[];
  var weekStart = firstMonday;
  while (!weekStart.isAfter(lastMonday)) {
    final week = <HeatmapCell>[];
    for (var i = 0; i < 7; i++) {
      final date =
          DateTime(weekStart.year, weekStart.month, weekStart.day + i);
      final CellState state;
      if (date.isAfter(t)) {
        state = CellState.future;
      } else if (date.isBefore(created)) {
        state = CellState.beforeCreation;
      } else if (days.contains(date)) {
        state = CellState.completed;
      } else {
        state = CellState.notCompleted;
      }
      week.add(HeatmapCell(date, state));
    }
    weeks.add(week);
    weekStart = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
  }
  return HeatmapData(weeks);
}
```

- [ ] **Step 4: Run to verify pass**

```bash
flutter test test/domain/heatmap_test.dart
```
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/heatmap.dart test/domain/heatmap_test.dart
git commit -m "feat(domain): add heatmap grid model"
```

---

### Task 4: Extend providers (summary fields + detail provider)

**Files:**
- Modify: `lib/state/habit_providers.dart`
- Modify (generated): `lib/state/habit_providers.g.dart`
- Test: `test/state/habit_providers_test.dart`

`HabitSummary` gains `dates` and `completionPercent` so the home card can render its mini-heatmap and %. A new `habitDetailProvider(id)` derives a single habit's summary from the same reactive stream so detail-screen edits propagate everywhere.

- [ ] **Step 1: Replace `lib/state/habit_providers.dart`**

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/database.dart';
import '../data/habit_dao.dart';
import '../domain/completion_stats.dart';
import '../domain/dates.dart';
import '../domain/streak.dart';

part 'habit_providers.g.dart';

/// View-model for one habit (home card and detail screen).
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
          completionPercent:
              completionPercent(row.dates, row.habit.createdAt, today),
          dates: row.dates,
        ),
    ];
  });
}

/// A single habit's summary, derived from [habitSummariesProvider]. Returns null
/// while loading or after the habit has been deleted.
@riverpod
HabitSummary? habitDetail(Ref ref, int habitId) {
  final summaries = ref.watch(habitSummariesProvider).valueOrNull;
  if (summaries == null) return null;
  for (final s in summaries) {
    if (s.habit.id == habitId) return s;
  }
  return null;
}
```

- [ ] **Step 2: Regenerate code**

```bash
dart run build_runner build --delete-conflicting-outputs
```
Expected: `habit_providers.g.dart` updated with `habitDetailProvider`. No errors.

- [ ] **Step 3: Update `test/state/habit_providers_test.dart`** — replace its contents:

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/database.dart';
import 'package:habbits/domain/dates.dart';
import 'package:habbits/state/habit_providers.dart';

void main() {
  test('habitSummaries computes streak, doneToday, percent, and dates', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    final id = await container.read(habitDaoProvider).createHabit(name: 'Read', color: 1);
    final today = dateOnly(DateTime.now());
    await container.read(habitDaoProvider).toggleCompletion(id, today);

    final summaries = await container.read(habitSummariesProvider.future);
    final s = summaries.single;
    expect(s.habit.name, 'Read');
    expect(s.streak, 1);
    expect(s.doneToday, isTrue);
    expect(s.completionPercent, 100); // created today, checked today
    expect(s.dates, {today});
  });

  test('habitDetail returns the matching habit summary', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    // Keep the source stream alive so the derived provider has data.
    final sub = container.listen(habitSummariesProvider, (_, __) {});
    addTearDown(sub.close);

    final id = await container.read(habitDaoProvider).createHabit(name: 'Walk', color: 1);
    await container.read(habitSummariesProvider.future);

    final detail = container.read(habitDetailProvider(id));
    expect(detail, isNotNull);
    expect(detail!.habit.name, 'Walk');

    final missing = container.read(habitDetailProvider(9999));
    expect(missing, isNull);
  });
}
```

- [ ] **Step 4: Run to verify pass**

```bash
flutter test test/state/habit_providers_test.dart
```
Expected: PASS (2 tests). If the first run fails to compile on a missing `*.g.dart`, re-run Step 2 then this.

- [ ] **Step 5: Commit**

```bash
git add lib/state/habit_providers.dart lib/state/habit_providers.g.dart test/state/habit_providers_test.dart
git commit -m "feat(state): add dates + completionPercent to HabitSummary and a habitDetail provider"
```

---

### Task 5: Reusable heatmap widget

**Files:**
- Create: `lib/ui/widgets/heatmap_grid.dart`
- Test: `test/ui/heatmap_grid_test.dart`

One widget renders any `HeatmapData`. Read-only on the home card; interactive on detail (taps on in-range cells call `onToggle`; future/before-creation cells and the read-only mode never fire).

- [ ] **Step 1: Write the failing widget test** — create `test/ui/heatmap_grid_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/heatmap.dart';
import 'package:habbits/ui/widgets/heatmap_grid.dart';

HeatmapData _oneWeek() {
  // Mon..Sun with a known mix of states.
  final monday = DateTime(2026, 6, 8);
  DateTime d(int i) => DateTime(monday.year, monday.month, monday.day + i);
  return HeatmapData([
    [
      HeatmapCell(d(0), CellState.completed),
      HeatmapCell(d(1), CellState.notCompleted),
      HeatmapCell(d(2), CellState.beforeCreation),
      HeatmapCell(d(3), CellState.notCompleted),
      HeatmapCell(d(4), CellState.notCompleted),
      HeatmapCell(d(5), CellState.notCompleted),
      HeatmapCell(d(6), CellState.future),
    ],
  ]);
}

void main() {
  testWidgets('interactive: tapping an in-range cell calls onToggle with its date',
      (tester) async {
    DateTime? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HeatmapGrid(
          data: _oneWeek(),
          color: Colors.teal,
          interactive: true,
          onToggle: (date) => tapped = date,
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('heatmap-cell-2026-06-09'))); // notCompleted
    expect(tapped, DateTime(2026, 6, 9));
  });

  testWidgets('interactive: future and beforeCreation cells do not fire onToggle',
      (tester) async {
    DateTime? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HeatmapGrid(
          data: _oneWeek(),
          color: Colors.teal,
          interactive: true,
          onToggle: (date) => tapped = date,
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('heatmap-cell-2026-06-14'))); // future
    await tester.tap(find.byKey(const Key('heatmap-cell-2026-06-10'))); // beforeCreation
    expect(tapped, isNull);
  });

  testWidgets('non-interactive: tapping an in-range cell does nothing', (tester) async {
    DateTime? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HeatmapGrid(
          data: _oneWeek(),
          color: Colors.teal,
          onToggle: (date) => tapped = date, // ignored because interactive defaults false
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('heatmap-cell-2026-06-09')));
    expect(tapped, isNull);
  });
}
```

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/ui/heatmap_grid_test.dart
```
Expected: FAIL — `heatmap_grid.dart` does not exist.

- [ ] **Step 3: Implement `lib/ui/widgets/heatmap_grid.dart`**

```dart
import 'package:flutter/material.dart';

import '../../domain/dates.dart';
import '../../domain/heatmap.dart';

/// Renders a [HeatmapData] as columns of weeks (each 7 cells, Monday..Sunday).
/// When [interactive] is true, tapping a completed/notCompleted cell calls
/// [onToggle] with that cell's date; future and before-creation cells never fire.
class HeatmapGrid extends StatelessWidget {
  const HeatmapGrid({
    super.key,
    required this.data,
    required this.color,
    this.interactive = false,
    this.onToggle,
    this.cellSize = 14,
    this.cellGap = 3,
  });

  final HeatmapData data;
  final Color color;
  final bool interactive;
  final void Function(DateTime date)? onToggle;
  final double cellSize;
  final double cellGap;

  bool _editable(CellState s) =>
      s == CellState.completed || s == CellState.notCompleted;

  Color _cellColor(BuildContext context, CellState state) {
    switch (state) {
      case CellState.completed:
        return color;
      case CellState.notCompleted:
        return color.withValues(alpha: 0.15);
      case CellState.future:
      case CellState.beforeCreation:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final week in data.weeks)
          Padding(
            padding: EdgeInsets.only(right: cellGap),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final cell in week)
                  Padding(
                    padding: EdgeInsets.only(bottom: cellGap),
                    child: _Cell(
                      key: ValueKey('heatmap-cell-${formatIsoDate(cell.date)}'),
                      size: cellSize,
                      color: _cellColor(context, cell.state),
                      onTap: interactive && _editable(cell.state) && onToggle != null
                          ? () => onToggle!(cell.date)
                          : null,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({super.key, required this.size, required this.color, this.onTap});
  final double size;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
```

Note: `Color.withValues(alpha:)` is current Flutter (3.27+); if your SDK predates it, use `color.withOpacity(0.15)`.

- [ ] **Step 4: Run to verify pass**

```bash
flutter test test/ui/heatmap_grid_test.dart
```
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/widgets/heatmap_grid.dart test/ui/heatmap_grid_test.dart
git commit -m "feat(ui): add reusable heatmap grid widget"
```

---

### Task 6: Extract shared habit dialogs

**Files:**
- Create: `lib/ui/widgets/habit_dialogs.dart`
- Modify: `lib/ui/habit_list/habit_list_screen.dart`
- Test: existing `test/ui/habit_list_screen_test.dart` must stay green

The detail screen (Task 7) needs the same rename/delete dialogs the home screen has. Extract the two private helpers into public functions so both screens share them. `confirmDeleteHabit` returns whether the habit was deleted, so the detail screen can pop afterward.

- [ ] **Step 1: Create `lib/ui/widgets/habit_dialogs.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/habit_providers.dart';

/// Shows the create/rename name dialog. With [habitId] null it creates a new
/// habit; otherwise it renames the given habit.
Future<void> showHabitNameDialog(
  BuildContext context,
  WidgetRef ref, {
  int? habitId,
  String? initial,
}) async {
  final dao = ref.read(habitDaoProvider);
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
  if (habitId == null) {
    await dao.createHabit(name: name, color: Colors.teal.toARGB32());
  } else {
    await dao.renameHabit(habitId, name);
  }
}

/// Shows the permanent-delete confirmation. Returns true if the habit was
/// deleted, false if the user cancelled.
Future<bool> confirmDeleteHabit(
  BuildContext context,
  WidgetRef ref,
  int habitId,
  String name,
) async {
  final dao = ref.read(habitDaoProvider);
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
    await dao.deleteHabit(habitId);
    return true;
  }
  return false;
}
```

- [ ] **Step 2: Update `lib/ui/habit_list/habit_list_screen.dart` to use the shared dialogs**

Remove the private `_showNameDialog` and `_confirmDelete` functions (the entire two functions at the bottom of the file), add the import, and update the call sites. The file becomes:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dates.dart';
import '../../state/habit_providers.dart';
import '../widgets/habit_dialogs.dart';

class HabitListScreen extends ConsumerWidget {
  const HabitListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(habitSummariesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Habbits')),
      floatingActionButton: FloatingActionButton(
        key: const Key('add-habit-fab'),
        onPressed: () => showHabitNameDialog(context, ref),
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
        key: ValueKey('checkoff-toggle-${item.habit.id}'),
        value: item.doneToday,
        onChanged: (_) =>
            dao.toggleCompletion(item.habit.id, dateOnly(DateTime.now())),
      ),
      title: Text(item.habit.name),
      subtitle: Text('Streak: ${item.streak}'),
      trailing: PopupMenuButton<String>(
        key: ValueKey('habit-menu-${item.habit.id}'),
        onSelected: (value) {
          if (value == 'rename') {
            showHabitNameDialog(context, ref,
                habitId: item.habit.id, initial: item.habit.name);
          } else if (value == 'delete') {
            confirmDeleteHabit(context, ref, item.habit.id, item.habit.name);
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
```

(This is a pure refactor — Task 8 rebuilds the tile into the card. Doing the extract first keeps each diff focused and keeps the existing tests green here.)

- [ ] **Step 3: Run the existing UI + full suite**

```bash
flutter test test/ui/habit_list_screen_test.dart
flutter analyze
```
Expected: the 4 existing habit-list tests PASS unchanged; analyze clean.

- [ ] **Step 4: Commit**

```bash
git add lib/ui/widgets/habit_dialogs.dart lib/ui/habit_list/habit_list_screen.dart
git commit -m "refactor(ui): extract shared habit name/delete dialogs"
```

---

### Task 7: Habit detail screen

**Files:**
- Create: `lib/ui/habit_detail/habit_detail_screen.dart`
- Test: `test/ui/habit_detail_screen_test.dart`

Full scrollable heatmap + streak + 30-day % + retroactive editing + rename/delete. Reads `habitDetailProvider(id)`; toggling a heatmap cell calls `toggleCompletion(id, date)`.

- [ ] **Step 1: Write the failing widget test** — create `test/ui/habit_detail_screen_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
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
```

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/ui/habit_detail_screen_test.dart
```
Expected: FAIL — `habit_detail_screen.dart` does not exist.

- [ ] **Step 3: Implement `lib/ui/habit_detail/habit_detail_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dates.dart';
import '../../domain/heatmap.dart';
import '../../state/habit_providers.dart';
import '../widgets/habit_dialogs.dart';
import '../widgets/heatmap_grid.dart';

class HabitDetailScreen extends ConsumerWidget {
  const HabitDetailScreen({super.key, required this.habitId});
  final int habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(habitDetailProvider(habitId));

    if (summary == null) {
      return const Scaffold(
        key: Key('habit-detail-screen'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final dao = ref.read(habitDaoProvider);
    final today = dateOnly(DateTime.now());
    final data = buildHeatmap(
      completed: summary.dates,
      createdAt: summary.habit.createdAt,
      today: today,
    );
    final percent = summary.completionPercent;

    return Scaffold(
      key: const Key('habit-detail-screen'),
      appBar: AppBar(
        title: Text(summary.habit.name),
        actions: [
          IconButton(
            key: const Key('detail-rename'),
            icon: const Icon(Icons.edit),
            tooltip: 'Rename',
            onPressed: () => showHabitNameDialog(
              context,
              ref,
              habitId: habitId,
              initial: summary.habit.name,
            ),
          ),
          IconButton(
            key: const Key('detail-delete'),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: () async {
              final deleted = await confirmDeleteHabit(
                  context, ref, habitId, summary.habit.name);
              if (deleted && context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Streak: ${summary.streak}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('30-day: ${percent == null ? '—' : '$percent%'}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: HeatmapGrid(
              data: data,
              color: Color(summary.habit.color),
              interactive: true,
              cellSize: 18,
              onToggle: (date) => dao.toggleCompletion(habitId, date),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run to verify pass**

```bash
flutter test test/ui/habit_detail_screen_test.dart
```
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/habit_detail/habit_detail_screen.dart test/ui/habit_detail_screen_test.dart
git commit -m "feat(ui): add habit detail screen with full heatmap and retroactive editing"
```

---

### Task 8: Rework the home card

**Files:**
- Modify: `lib/ui/habit_list/habit_list_screen.dart`
- Modify: `test/ui/habit_list_screen_test.dart`

Replace the plain `ListTile` with a card showing name, streak, a read-only mini-heatmap, the 30-day %, and a dedicated `Checkbox` check-off for today. Tapping the card body navigates to the detail screen. Delete moves to detail (the home popup menu is removed). The `Checkbox` and the `Streak: N` / `Medicine` text are KEPT so the merged integration test (`find.byType(Checkbox)`, `find.text('Streak: 1')`) and the existing widget tests still pass.

- [ ] **Step 1: Update `test/ui/habit_list_screen_test.dart`** — replace its contents (keeps the add/check-off/two-habit cases, drops the home delete case which now lives on detail, adds a navigation case):

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

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(find.text('Streak: 1'), findsOneWidget);
  });

  testWidgets('two habits each render with independent check-off controls',
      (tester) async {
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
}
```

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/ui/habit_list_screen_test.dart
```
Expected: FAIL — the navigation test fails (no detail wired) and/or the card structure differs.

- [ ] **Step 3: Replace `_HabitTile` in `lib/ui/habit_list/habit_list_screen.dart`**

Update the imports at the top of the file to add the heatmap pieces and the detail screen, and replace the entire `_HabitTile` class with `_HabitCard`. The full file:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dates.dart';
import '../../domain/heatmap.dart';
import '../../state/habit_providers.dart';
import '../habit_detail/habit_detail_screen.dart';
import '../widgets/habit_dialogs.dart';
import '../widgets/heatmap_grid.dart';

class HabitListScreen extends ConsumerWidget {
  const HabitListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(habitSummariesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Habbits')),
      floatingActionButton: FloatingActionButton(
        key: const Key('add-habit-fab'),
        onPressed: () => showHabitNameDialog(context, ref),
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
            children: [for (final item in items) _HabitCard(item: item)],
          );
        },
      ),
    );
  }
}

class _HabitCard extends ConsumerWidget {
  const _HabitCard({required this.item});
  final HabitSummary item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dao = ref.read(habitDaoProvider);
    final today = dateOnly(DateTime.now());
    final percent = item.completionPercent;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HabitDetailScreen(habitId: item.habit.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.habit.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text('Streak: ${item.streak}'),
                  Checkbox(
                    key: ValueKey('checkoff-toggle-${item.habit.id}'),
                    value: item.doneToday,
                    onChanged: (_) => dao.toggleCompletion(item.habit.id, today),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  const cellSize = 11.0;
                  const cellGap = 2.0;
                  final weeks =
                      (constraints.maxWidth / (cellSize + cellGap)).floor().clamp(1, 26);
                  final data = buildHeatmap(
                    completed: item.dates,
                    createdAt: item.habit.createdAt,
                    today: today,
                    maxWeeks: weeks,
                  );
                  return HeatmapGrid(
                    data: data,
                    color: Color(item.habit.color),
                    cellSize: cellSize,
                    cellGap: cellGap,
                  );
                },
              ),
              const SizedBox(height: 8),
              Text('30-day: ${percent == null ? '—' : '$percent%'}'),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the UI suite to verify pass**

```bash
flutter test test/ui/habit_list_screen_test.dart
```
Expected: PASS (4 tests, including navigation to detail).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/habit_list/habit_list_screen.dart test/ui/habit_list_screen_test.dart
git commit -m "feat(ui): rework home into habit cards with mini-heatmap, percent, and detail nav"
```

---

### Task 9: Final verification

No code changes — verify the whole slice and the unaffected suites.

- [ ] **Step 1: Analyze**

```bash
flutter analyze
```
Expected: `No issues found!`.

- [ ] **Step 2: Full unit + widget suite**

```bash
flutter test
```
Expected: all green — domain (dates, streak, completion_stats, heatmap), data (database, habit_dao), state (habit_providers), ui (heatmap_grid, habit_list_screen, habit_detail_screen). The merged `critical_flow` integration test is not run here (needs an emulator) and is unaffected: the home card keeps a `Checkbox` and the `Streak: N` / habit-name text it relies on.

- [ ] **Step 3: Confirm clean tree**

```bash
git status
git log --oneline -9 | cat
```
Expected: clean working tree; the 8 implementation commits present.

---

## Self-review notes

- **Spec coverage:**
  - §1 home cards (name, streak, read-only mini-heatmap, %, dedicated check button, tap→detail): Task 8.
  - §1 detail screen (full scrollable heatmap, streak, %, retroactive edit, rename, delete): Task 7.
  - §2 heatmap model (weeks×weekdays Mon→Sun, four cell states, in-range = createdAt…today, mini maxWeeks vs full, no-future/no-pre-creation taps): Tasks 1 (`mondayOf`), 3 (`buildHeatmap`), 5 (gesture gating).
  - §3 30-day % (rule + day-0 "—" edge): Task 2 (+ Task 1 `daysBetween`), surfaced in Tasks 4/7/8.
  - §4 architecture (new files, HabitSummary fields, habitDetailProvider, one reusable widget, GridView/Row rendering): Tasks 4, 5, 6, 7, 8.
  - §5 testing (domain table-driven; widget; regression of the reworked home tests; integration test untouched): each task's tests + Task 9.
- **Placeholder scan:** none. The `withValues`/`withOpacity` and `toARGB32`/`.value` fallbacks are flagged inline, not left ambiguous. Mini-heatmap week count is computed from width (LayoutBuilder), not a magic guess.
- **Type/name consistency:** `HabitSummary` fields (`habit`, `streak`, `doneToday`, `completionPercent`, `dates`) defined in Task 4 and consumed identically in Tasks 7–8; `completionPercent(Set<DateTime>, DateTime, DateTime) -> int?` (Task 2) called in Task 4; `buildHeatmap({completed, createdAt, today, maxWeeks})` / `HeatmapData.weeks` / `HeatmapCell(date,state)` / `CellState` (Task 3) consumed in Tasks 5, 7, 8; `HeatmapGrid({data, color, interactive, onToggle, cellSize, cellGap})` (Task 5) used in Tasks 7–8; cell key format `heatmap-cell-<iso>` consistent between Task 5 and the Task 7 retroactive test; `showHabitNameDialog` / `confirmDeleteHabit` (Task 6) used in Tasks 6–8; detail Scaffold key `habit-detail-screen` consistent between Tasks 7 and 8; the home `Checkbox` + `Streak: N` text preserved (Task 8) so the merged integration test stays valid.
- **Known judgment calls:** mini-heatmap is read-only (editing only on detail, per spec); delete removed from the home card (moved to detail) — the old home delete test is relocated to Task 7; `habitDetail` returns null for both "loading" and "deleted" (acceptable — detail is always opened from an already-loaded list, and a delete pops the route).

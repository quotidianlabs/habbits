---
status: shipped
date: 2026-06-13
slug: usability-v2
spec: usability-v2
pr: merged to main locally
---

# Usability v2 (compact home + recent-days list) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make home cards compact (one-row 14-day strip instead of the 7-row mini-heatmap) and make the detail screen editable by an unambiguous newest-first 30-day list, with the heatmap there becoming a read-only picture.

**Architecture:** A new pure `recentDays` helper (shared by both new widgets) plus a pure `calendar_labels` helper. Two new thin widgets — `DayStrip` (home, read-only) and `RecentDaysList` (detail, toggles a day). The detail screen composes a read-only `HeatmapGrid` + `RecentDaysList`; the home card composes an info line + `DayStrip`. `HeatmapGrid`'s now-unused interactive/tap path is pruned last. No schema/state change.

**Tech Stack:** Flutter (Material 3), Drift, Riverpod. Pure-Dart domain helpers.

**Source spec:** `docs/superpowers/specs/2026-06-13-usability-v2-design.md`.

**Pre-flight:** Flutter on PATH (`/opt/homebrew/bin`; `export PATH="/opt/homebrew/bin:$PATH"` if needed). Branch `feat/usability-v2` (confirm `git branch --show-current`; if detached, STOP).

**Existing interfaces used (do not reimplement):**
- `lib/domain/dates.dart`: `dateOnly(DateTime)`, `formatIsoDate(DateTime)`.
- `lib/data/habit_dao.dart`: `toggleCompletion(int habitId, DateTime date)`.
- `lib/state/habit_providers.dart`: `habitDetailProvider(id)` → `HabitSummary?` with `.habit` (`.id`,`.name`,`.color` int,`.createdAt`), `.streak`, `.doneToday`, `.completionPercent` (int?), `.dates` (Set<DateTime>); `habitDaoProvider`; `habitSummariesProvider`.
- `lib/domain/heatmap.dart`: `buildHeatmap({completed, today, weeks})`, `HeatmapData`, `HeatmapCell`, `CellState`.

**Task ordering note:** `HeatmapGrid` keeps its `interactive`/`onToggle` params (default off) until **Task 7**; Tasks 5–6 stop passing them, then Task 7 prunes them together with their tests. This keeps every intermediate state compiling.

---

### Task 1: `recentDays` pure helper

**Files:**
- Create: `lib/domain/recent_days.dart`
- Test: `test/domain/recent_days_test.dart`

- [ ] **Step 1: Write the failing test** — `test/domain/recent_days_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/recent_days.dart';

void main() {
  final today = DateTime(2026, 6, 13);

  test('returns count days ending today, ordered oldest -> newest', () {
    final r = recentDays(const {}, today, 3);
    expect(r.length, 3);
    expect(r.first.date, DateTime(2026, 6, 11));
    expect(r.last.date, DateTime(2026, 6, 13));
  });

  test('marks completed days', () {
    final r = recentDays({DateTime(2026, 6, 12)}, today, 3);
    expect(r[0].completed, isFalse); // Jun 11
    expect(r[1].completed, isTrue);  // Jun 12
    expect(r[2].completed, isFalse); // Jun 13
  });

  test('normalizes time components in inputs', () {
    final r = recentDays({DateTime(2026, 6, 13, 9)}, DateTime(2026, 6, 13, 23), 1);
    expect(r.single.date, DateTime(2026, 6, 13));
    expect(r.single.completed, isTrue);
  });

  test('never includes a future day (ends at today)', () {
    final r = recentDays(const {}, today, 5);
    expect(r.last.date, today);
    expect(r.every((d) => !d.date.isAfter(today)), isTrue);
  });

  test('crosses a month boundary correctly', () {
    final r = recentDays(const {}, DateTime(2026, 3, 1), 3);
    expect(r.first.date, DateTime(2026, 2, 27));
    expect(r.last.date, DateTime(2026, 3, 1));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/domain/recent_days_test.dart
```
Expected: FAIL — file/function undefined.

- [ ] **Step 3: Implement `lib/domain/recent_days.dart`**

```dart
import 'dates.dart';

/// One day in a recent-days window.
class RecentDay {
  const RecentDay(this.date, this.completed);
  final DateTime date;
  final bool completed;
}

/// The last [count] days ending today (inclusive), ordered oldest -> newest.
/// `completed` is whether that date is in [completed]. Never includes future
/// days. All inputs are normalized to date-only; DST-safe via date construction.
List<RecentDay> recentDays(Set<DateTime> completed, DateTime today, int count) {
  final days = completed.map(dateOnly).toSet();
  final t = dateOnly(today);
  final result = <RecentDay>[];
  for (var i = count - 1; i >= 0; i--) {
    final date = DateTime(t.year, t.month, t.day - i);
    result.add(RecentDay(date, days.contains(date)));
  }
  return result;
}
```

- [ ] **Step 4: Run to verify it passes**

```bash
flutter test test/domain/recent_days_test.dart
```
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/recent_days.dart test/domain/recent_days_test.dart
git commit -m "feat(domain): add recentDays helper for the strip and day list"
```

---

### Task 2: `calendar_labels` pure helper

**Files:**
- Create: `lib/domain/calendar_labels.dart`
- Test: `test/domain/calendar_labels_test.dart`

Shared 3-letter month/weekday abbreviations (used by the day list now and by the heatmap month labels in Task 7).

- [ ] **Step 1: Write the failing test** — `test/domain/calendar_labels_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/calendar_labels.dart';

void main() {
  test('monthAbbr3 maps 1..12 to Jan..Dec', () {
    expect(monthAbbr3(1), 'Jan');
    expect(monthAbbr3(6), 'Jun');
    expect(monthAbbr3(12), 'Dec');
  });

  test('weekdayAbbr3 maps 1..7 to Mon..Sun (DateTime.weekday)', () {
    expect(weekdayAbbr3(1), 'Mon');
    expect(weekdayAbbr3(6), 'Sat');
    expect(weekdayAbbr3(7), 'Sun');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/domain/calendar_labels_test.dart
```
Expected: FAIL — undefined.

- [ ] **Step 3: Implement `lib/domain/calendar_labels.dart`**

```dart
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// 3-letter month abbreviation for [month] (1 = Jan .. 12 = Dec).
String monthAbbr3(int month) => _months[month - 1];

/// 3-letter weekday abbreviation for [weekday] (1 = Mon .. 7 = Sun, matching
/// `DateTime.weekday`).
String weekdayAbbr3(int weekday) => _weekdays[weekday - 1];
```

- [ ] **Step 4: Run to verify it passes**

```bash
flutter test test/domain/calendar_labels_test.dart
```
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/calendar_labels.dart test/domain/calendar_labels_test.dart
git commit -m "feat(domain): add shared month/weekday abbreviation helpers"
```

---

### Task 3: `DayStrip` widget (home one-row strip)

**Files:**
- Create: `lib/ui/widgets/day_strip.dart`
- Test: `test/ui/day_strip_test.dart`

- [ ] **Step 1: Write the failing test** — `test/ui/day_strip_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/ui/widgets/day_strip.dart';

void main() {
  testWidgets('renders one keyed cell per day in the window', (tester) async {
    final today = DateTime(2026, 6, 13);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DayStrip(
          completed: {DateTime(2026, 6, 12)},
          today: today,
          color: Colors.teal,
          count: 14,
        ),
      ),
    ));
    // Today and the 13-days-before cell are present; one day past the window is not.
    expect(find.byKey(const Key('daystrip-2026-06-13')), findsOneWidget); // today
    expect(find.byKey(const Key('daystrip-2026-05-31')), findsOneWidget); // today-13
    expect(find.byKey(const Key('daystrip-2026-05-30')), findsNothing);   // today-14
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/ui/day_strip_test.dart
```
Expected: FAIL — `day_strip.dart` does not exist.

- [ ] **Step 3: Implement `lib/ui/widgets/day_strip.dart`**

```dart
import 'package:flutter/material.dart';

import '../../domain/dates.dart';
import '../../domain/recent_days.dart';

/// A read-only one-row strip of the last [count] days (oldest -> newest).
class DayStrip extends StatelessWidget {
  const DayStrip({
    super.key,
    required this.completed,
    required this.today,
    required this.color,
    this.count = 14,
    this.cellSize = 12,
    this.cellGap = 3,
  });

  final Set<DateTime> completed;
  final DateTime today;
  final Color color;
  final int count;
  final double cellSize;
  final double cellGap;

  @override
  Widget build(BuildContext context) {
    final days = recentDays(completed, today, count);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final day in days)
          Padding(
            padding: EdgeInsets.only(right: cellGap),
            child: Container(
              key: ValueKey('daystrip-${formatIsoDate(day.date)}'),
              width: cellSize,
              height: cellSize,
              decoration: BoxDecoration(
                color: day.completed ? color : color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
      ],
    );
  }
}
```

Note: `Color.withValues(alpha:)` is current Flutter (3.27+); 3.44 here supports it.

- [ ] **Step 4: Run to verify it passes**

```bash
flutter test test/ui/day_strip_test.dart
```
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/widgets/day_strip.dart test/ui/day_strip_test.dart
git commit -m "feat(ui): add DayStrip one-row recent-activity widget"
```

---

### Task 4: `RecentDaysList` widget (detail editing list)

**Files:**
- Create: `lib/ui/widgets/recent_days_list.dart`
- Test: `test/ui/recent_days_list_test.dart`

- [ ] **Step 1: Write the failing test** — `test/ui/recent_days_list_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/ui/widgets/recent_days_list.dart';

void main() {
  final today = DateTime(2026, 6, 13);

  Widget host({required void Function(DateTime) onToggle, Set<DateTime> done = const {}}) =>
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecentDaysList(
              completed: done,
              today: today,
              count: 5,
              onToggle: onToggle,
            ),
          ),
        ),
      );

  testWidgets('lists the last N days newest-first with today labeled', (tester) async {
    await tester.pumpWidget(host(onToggle: (_) {}, done: {DateTime(2026, 6, 12)}));
    expect(find.textContaining('Today'), findsOneWidget);
    expect(find.byKey(const Key('daylist-2026-06-13')), findsOneWidget); // today
    expect(find.byKey(const Key('daylist-2026-06-09')), findsOneWidget); // today-4
    expect(find.byKey(const Key('daylist-2026-06-08')), findsNothing);   // outside window
  });

  testWidgets('tapping a row calls onToggle with that date', (tester) async {
    DateTime? toggled;
    await tester.pumpWidget(host(onToggle: (d) => toggled = d));
    await tester.tap(find.byKey(const Key('daylist-2026-06-11')));
    expect(toggled, DateTime(2026, 6, 11));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/ui/recent_days_list_test.dart
```
Expected: FAIL — `recent_days_list.dart` does not exist.

- [ ] **Step 3: Implement `lib/ui/widgets/recent_days_list.dart`**

```dart
import 'package:flutter/material.dart';

import '../../domain/calendar_labels.dart';
import '../../domain/dates.dart';
import '../../domain/recent_days.dart';

/// A newest-first list of the last [count] days. Tapping a row (or its checkbox)
/// calls [onToggle] with that day's date.
class RecentDaysList extends StatelessWidget {
  const RecentDaysList({
    super.key,
    required this.completed,
    required this.today,
    required this.onToggle,
    this.count = 30,
  });

  final Set<DateTime> completed;
  final DateTime today;
  final void Function(DateTime date) onToggle;
  final int count;

  String _label(DateTime date) {
    final base = '${weekdayAbbr3(date.weekday)}, ${monthAbbr3(date.month)} ${date.day}';
    return date == dateOnly(today) ? 'Today · $base' : base;
  }

  @override
  Widget build(BuildContext context) {
    final days = recentDays(completed, today, count).reversed.toList(); // newest first
    return Column(
      children: [
        for (final day in days)
          ListTile(
            key: ValueKey('daylist-${formatIsoDate(day.date)}'),
            dense: true,
            title: Text(_label(day.date)),
            trailing: Checkbox(
              value: day.completed,
              onChanged: (_) => onToggle(day.date),
            ),
            onTap: () => onToggle(day.date),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run to verify it passes**

```bash
flutter test test/ui/recent_days_list_test.dart
```
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/widgets/recent_days_list.dart test/ui/recent_days_list_test.dart
git commit -m "feat(ui): add RecentDaysList editable day list"
```

---

### Task 5: Detail screen — read-only heatmap + RecentDaysList

**Files:**
- Modify: `lib/ui/habit_detail/habit_detail_screen.dart`
- Modify: `test/ui/habit_detail_screen_test.dart`

Make the heatmap read-only (drop `interactive`/`onToggle` from the call — `HeatmapGrid` still has those params with defaults, so this compiles) and add the `RecentDaysList` as the editing surface.

- [ ] **Step 1: Update the retroactive test in `test/ui/habit_detail_screen_test.dart`**

Replace the test named `'tapping a past in-range cell records a completion (retroactive)'` (the one that taps `find.byKey(Key('heatmap-cell-$iso'))`) with this version that taps a day-list row instead. Leave the other tests (renders, "—" branch, rename, delete) unchanged:

```dart
  testWidgets('tapping a day row records a completion (retroactive)',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await seedHabit(db);

    await tester.pumpWidget(app(db, id));
    await tester.pumpAndSettle();

    final target = dateOnly(DateTime.now()).subtract(const Duration(days: 3));
    final iso = formatIsoDate(target);
    await tester.tap(find.byKey(Key('daylist-$iso')));
    await tester.pumpAndSettle();

    final rows = await (db.select(db.completions)
          ..where((c) => c.localDate.equals(iso)))
        .get();
    expect(rows, hasLength(1));
  });
```

(The existing `seedHabit`, `app`, and imports `dates.dart`/`database.dart` are already in the file. The "renders ... the heatmap" test still asserts `find.byType(HeatmapGrid)` which remains present.)

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/ui/habit_detail_screen_test.dart
```
Expected: FAIL — `daylist-<iso>` key not found (no list yet).

- [ ] **Step 3: Replace `lib/ui/habit_detail/habit_detail_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dates.dart';
import '../../domain/heatmap.dart';
import '../../state/habit_providers.dart';
import '../widgets/habit_dialogs.dart';
import '../widgets/heatmap_grid.dart';
import '../widgets/recent_days_list.dart';

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
      today: today,
      weeks: 6,
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
              cellSize: 18,
              showMonthLabels: true,
            ),
          ),
          const SizedBox(height: 16),
          RecentDaysList(
            completed: summary.dates,
            today: today,
            onToggle: (date) => dao.toggleCompletion(habitId, date),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the detail tests + full suite**

```bash
flutter test test/ui/habit_detail_screen_test.dart
flutter test
```
Expected: detail tests PASS; full suite still green (the heatmap is still interactive-capable but unused here; its own tests are unchanged until Task 7).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/habit_detail/habit_detail_screen.dart test/ui/habit_detail_screen_test.dart
git commit -m "feat(ui): detail screen uses read-only heatmap + RecentDaysList for editing"
```

---

### Task 6: Home card — compact with DayStrip

**Files:**
- Modify: `lib/ui/habit_list/habit_list_screen.dart`
- Modify: `test/ui/habit_list_screen_test.dart`

Replace the tall card (7-row `HeatmapGrid`) with a 2-line compact card: an info Row (check + name + streak + %) and a `DayStrip`. Keep the `Checkbox` and `Streak: N` text (integration test). Remove the heatmap from home.

- [ ] **Step 1: Add a DayStrip assertion to `test/ui/habit_list_screen_test.dart`**

Add `import 'package:habbits/ui/widgets/day_strip.dart';` at the top, and to the first test (`'adding a habit shows it in the list'`), after the existing expects, add:

```dart
    expect(find.byType(DayStrip), findsOneWidget);
```

Leave the other three tests (check-off bumps streak, two habits, tapping a card opens detail) unchanged.

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/ui/habit_list_screen_test.dart
```
Expected: FAIL — `DayStrip` not present yet (and import unresolved until the card uses it).

- [ ] **Step 3: Replace `lib/ui/habit_list/habit_list_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dates.dart';
import '../../state/habit_providers.dart';
import '../habit_detail/habit_detail_screen.dart';
import '../widgets/day_strip.dart';
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
                  Checkbox(
                    key: ValueKey('checkoff-toggle-${item.habit.id}'),
                    value: item.doneToday,
                    onChanged: (_) => dao.toggleCompletion(item.habit.id, today),
                  ),
                  Expanded(
                    child: Text(
                      item.habit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text('Streak: ${item.streak}'),
                  const SizedBox(width: 12),
                  Text(percent == null ? '—' : '$percent%'),
                ],
              ),
              const SizedBox(height: 6),
              DayStrip(
                completed: item.dates,
                today: today,
                color: Color(item.habit.color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the home tests + full suite**

```bash
flutter test test/ui/habit_list_screen_test.dart
flutter test
```
Expected: 4 home tests PASS (incl. the new DayStrip assertion); full suite green.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/habit_list/habit_list_screen.dart test/ui/habit_list_screen_test.dart
git commit -m "feat(ui): compact home card with one-row DayStrip"
```

---

### Task 7: Prune `HeatmapGrid` interactive path

**Files:**
- Modify: `lib/ui/widgets/heatmap_grid.dart`
- Modify: `test/ui/heatmap_grid_test.dart`

Nothing passes `interactive`/`onToggle` anymore (detail dropped them in Task 5; home no longer uses `HeatmapGrid`). Remove them, drop the per-cell `GestureDetector`, and source month labels from `calendar_labels`.

- [ ] **Step 1: Replace `lib/ui/widgets/heatmap_grid.dart`**

```dart
import 'package:flutter/material.dart';

import '../../domain/calendar_labels.dart';
import '../../domain/dates.dart';
import '../../domain/heatmap.dart';

/// Renders a [HeatmapData] as columns of weeks (each 7 cells, Monday..Sunday).
/// Read-only — purely the activity picture. Optionally shows month labels.
class HeatmapGrid extends StatelessWidget {
  const HeatmapGrid({
    super.key,
    required this.data,
    required this.color,
    this.cellSize = 14,
    this.cellGap = 3,
    this.showMonthLabels = false,
  });

  final HeatmapData data;
  final Color color;
  final double cellSize;
  final double cellGap;
  final bool showMonthLabels;

  Color _cellColor(CellState state) {
    switch (state) {
      case CellState.completed:
        return color;
      case CellState.notCompleted:
        return color.withValues(alpha: 0.15);
      case CellState.future:
        return Colors.transparent;
    }
  }

  List<String?> _monthLabels() {
    final labels = <String?>[];
    int? lastMonth;
    for (final week in data.weeks) {
      final m = week.first.date.month;
      if (m != lastMonth) {
        labels.add(monthAbbr3(m));
        lastMonth = m;
      } else {
        labels.add(null);
      }
    }
    return labels;
  }

  Widget _labelsRow() {
    final labels = _monthLabels();
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

  Widget _grid() {
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
                    child: Container(
                      key: ValueKey('heatmap-cell-${formatIsoDate(cell.date)}'),
                      width: cellSize,
                      height: cellSize,
                      decoration: BoxDecoration(
                        color: _cellColor(cell.state),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!showMonthLabels) return _grid();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_labelsRow(), _grid()],
    );
  }
}
```

- [ ] **Step 2: Replace `test/ui/heatmap_grid_test.dart`** (remove the now-invalid interactive tests; keep render + month labels):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/heatmap.dart';
import 'package:habbits/ui/widgets/heatmap_grid.dart';

void main() {
  // A 6-week span crossing May -> June 2026 (May 4 is a Monday).
  HeatmapData multiMonth() {
    final weeks = <List<HeatmapCell>>[];
    var monday = DateTime(2026, 5, 4);
    for (var w = 0; w < 6; w++) {
      final week = <HeatmapCell>[];
      for (var i = 0; i < 7; i++) {
        final d = DateTime(monday.year, monday.month, monday.day + i);
        week.add(HeatmapCell(d, CellState.notCompleted));
      }
      weeks.add(week);
      monday = DateTime(monday.year, monday.month, monday.day + 7);
    }
    return HeatmapData(weeks);
  }

  testWidgets('renders a keyed cell per day', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: HeatmapGrid(data: multiMonth(), color: Colors.teal),
        ),
      ),
    ));
    expect(find.byKey(const Key('heatmap-cell-2026-06-08')), findsOneWidget);
  });

  testWidgets('showMonthLabels renders month abbreviations across the span',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: HeatmapGrid(
            data: multiMonth(),
            color: Colors.teal,
            showMonthLabels: true,
          ),
        ),
      ),
    ));
    expect(find.text('May'), findsOneWidget);
    expect(find.text('Jun'), findsOneWidget);
  });

  testWidgets('default has no month labels', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: HeatmapGrid(data: multiMonth(), color: Colors.teal),
        ),
      ),
    ));
    expect(find.text('May'), findsNothing);
    expect(find.text('Jun'), findsNothing);
  });
}
```

- [ ] **Step 3: Run the heatmap tests + analyze + full suite**

```bash
flutter test test/ui/heatmap_grid_test.dart
flutter analyze
flutter test
```
Expected: heatmap tests PASS (3); `flutter analyze` "No issues found!"; full suite green. If analyze flags an unused import or symbol from the prune, remove it.

- [ ] **Step 4: Commit**

```bash
git add lib/ui/widgets/heatmap_grid.dart test/ui/heatmap_grid_test.dart
git commit -m "refactor(ui): make HeatmapGrid read-only; share month labels via calendar_labels"
```

---

### Task 8: Final verification

No code changes.

- [ ] **Step 1: Analyze + full suite**

```bash
flutter analyze
flutter test
```
Expected: `No issues found!`; all tests pass (domain incl. recent_days + calendar_labels; widgets incl. day_strip, recent_days_list, heatmap_grid; screens incl. habit_detail, habit_list).

- [ ] **Step 2: Confirm clean tree + branch**

```bash
git status
git branch --show-current   # expect feat/usability-v2, NOT detached
git log --oneline -8 | cat
```
Expected: clean tree; on `feat/usability-v2`; the 7 implementation commits present.

The merged `integration_test/critical_flow_test.dart` is unaffected (not run here): the home card still has a `Checkbox`, the `Streak: N` text, and the habit-name text it asserts.

---

## Self-review notes

- **Spec coverage:**
  - §1 compact home card (check + name + streak + % line, one-row 14-day strip, no grid, `Streak: N` text kept): Tasks 3, 6.
  - §2 detail (read-only heatmap, newest-first 30-day list, tap-row toggles, future excluded): Tasks 4, 5; heatmap made read-only in Task 7.
  - §3 architecture (`recentDays` shared, `calendar_labels` DRY, `DayStrip`, `RecentDaysList`, `HeatmapGrid` pruned): Tasks 1–7.
  - §4 windows (strip 14, list 30, heatmap 6w; no future days): Task 3 (`count: 14`), Task 4 (`count: 30`), Task 5 (`weeks: 6`), Task 1 (no future).
  - §5 testing (pure recentDays; DayStrip/RecentDaysList widgets; updated detail/home; integration test preserved): each task's tests + Task 8.
- **Placeholder scan:** none. `withValues` is flagged with its version note.
- **Type/name consistency:** `recentDays(Set<DateTime>, DateTime, int) -> List<RecentDay>` (Task 1) consumed by `DayStrip` (3) and `RecentDaysList` (4); `RecentDay.date`/`.completed` used in both widgets; `monthAbbr3`/`weekdayAbbr3` (Task 2) used in `RecentDaysList` (4) and `HeatmapGrid` (7); cell/row key formats `daystrip-<iso>`, `daylist-<iso>`, `heatmap-cell-<iso>` consistent between widgets and their tests; `HeatmapGrid` is called with `interactive`/`onToggle` nowhere after Task 5, so removing them in Task 7 compiles; the home `Checkbox` + `Streak: N` text are preserved (Task 6) so the integration test stays valid.
- **Ordering:** leaf helpers/widgets (1–4) → consumers (5–6) → prune the now-unused path (7) → verify (8); every intermediate state compiles because `HeatmapGrid` keeps its (defaulted) interactive params until no caller uses them.

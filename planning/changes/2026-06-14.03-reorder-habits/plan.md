---
status: shipped
date: 2026-06-14
slug: reorder-habits
spec: reorder-habits
pr: 2c197d1
---

# Reorder Habits Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user drag a habit card (via a trailing handle) to reorder the home list, persisted to the `sortOrder` column, and fix `createHabit`'s count-based `sortOrder` so order is stable after deletes.

**Architecture:** A pure `reorderedIds` isolates `ReorderableListView`'s index convention. The DAO gains a transactional `reorderHabits(orderedIds)` and switches `createHabit` to `max(sortOrder)+1`. The home `ListView` becomes a `ReorderableListView` where each card has a `ValueKey` + a `ReorderableDragStartListener` drag handle; the reactive stream remains the single source of truth for order.

**Tech Stack:** Flutter (Material `ReorderableListView`), Drift, Riverpod.

**Source spec:** `docs/superpowers/specs/2026-06-14-reorder-habits-design.md`.

**Pre-flight:** Flutter on PATH (`/opt/homebrew/bin`; `export PATH="/opt/homebrew/bin:$PATH"`). Branch `feat/reorder-habits` (confirm `git branch --show-current`; if detached, STOP).

**Existing interfaces:** `lib/data/habit_dao.dart` → `HabitDao` with `createHabit` (currently `sortOrder: existing.length`), `deleteHabit`, `getHabitsWithDates()` (ordered by `sortOrder`). `Value` is imported from `package:drift/drift.dart`. `lib/state/habit_providers.dart` → `habitSummariesProvider`, `habitDaoProvider`, `HabitSummary{habit(.id/.name/.color), doneToday, completionPercent, dates}`. The home screen `lib/ui/habit_list/habit_list_screen.dart` renders a `ListView` of `_HabitCard`s and has a Settings app-bar action + an add FAB.

---

### Task 1: Pure `reorderedIds`

**Files:**
- Create: `lib/domain/reorder.dart`
- Test: `test/domain/reorder_test.dart`

The subtle part: `ReorderableListView.onReorder` reports `newIndex` as the slot *as if the dragged item were still present*, so a downward move needs `newIndex - 1`.

- [ ] **Step 1: Write the failing test** — `test/domain/reorder_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/reorder.dart';

void main() {
  test('moves the first item to the end', () {
    expect(reorderedIds([10, 20, 30], 0, 3), [20, 30, 10]);
  });

  test('moves the last item to the front', () {
    expect(reorderedIds([10, 20, 30], 2, 0), [30, 10, 20]);
  });

  test('moves an item down past one neighbour', () {
    // drag index 0 to just after index 1 -> newIndex 2 -> decremented to 1
    expect(reorderedIds([10, 20, 30], 0, 2), [20, 10, 30]);
  });

  test('moves an item up by one', () {
    expect(reorderedIds([10, 20, 30], 1, 0), [20, 10, 30]);
  });

  test('single-item list is unchanged', () {
    expect(reorderedIds([10], 0, 1), [10]);
  });

  test('does not mutate the input list', () {
    final input = [10, 20, 30];
    reorderedIds(input, 0, 2);
    expect(input, [10, 20, 30]);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/domain/reorder_test.dart
```
Expected: FAIL — `reorderedIds` undefined.

- [ ] **Step 3: Implement `lib/domain/reorder.dart`**

```dart
/// Returns a new list with the item at [oldIndex] moved to [newIndex], applying
/// `ReorderableListView`'s index convention: when moving an item downward,
/// [newIndex] is one past the intended slot, so it is decremented. Does not
/// mutate [ids].
List<int> reorderedIds(List<int> ids, int oldIndex, int newIndex) {
  final list = [...ids];
  var target = newIndex;
  if (target > oldIndex) target -= 1;
  final item = list.removeAt(oldIndex);
  list.insert(target, item);
  return list;
}
```

- [ ] **Step 4: Run to verify it passes**

```bash
flutter test test/domain/reorder_test.dart
```
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/reorder.dart test/domain/reorder_test.dart
git commit -m "feat(domain): add reorderedIds helper"
```

---

### Task 2: DAO `reorderHabits` + `createHabit` integrity fix

**Files:**
- Modify: `lib/data/habit_dao.dart`
- Test: `test/data/habit_dao_test.dart`

- [ ] **Step 1: Add failing tests** — append inside the existing `main()` in `test/data/habit_dao_test.dart`:

```dart
  test('reorderHabits rewrites sortOrder to the new order', () async {
    await dao.createHabit(name: 'A', color: 1);
    final b = await dao.createHabit(name: 'B', color: 1);
    final c = await dao.createHabit(name: 'C', color: 1);
    final a = (await dao.getHabitsWithDates()).first.habit.id; // A is first

    await dao.reorderHabits([c, a, b]);

    final rows = await dao.getHabitsWithDates();
    expect(rows.map((r) => r.habit.name), ['C', 'A', 'B']);
    expect(rows.map((r) => r.habit.sortOrder), [0, 1, 2]);
  });

  test('createHabit gives a unique trailing sortOrder after a delete', () async {
    await dao.createHabit(name: 'A', color: 1); // sortOrder 0
    final b = await dao.createHabit(name: 'B', color: 1); // 1
    await dao.createHabit(name: 'C', color: 1); // 2

    await dao.deleteHabit(b);
    final d = await dao.createHabit(name: 'D', color: 1); // must NOT collide with C(2)

    final rows = await dao.getHabitsWithDates();
    expect(rows.map((r) => r.habit.name), ['A', 'C', 'D']);
    final dRow = rows.firstWhere((r) => r.habit.id == d);
    expect(dRow.habit.sortOrder, 3); // max(0,2)+1
    // sort orders are all distinct
    final orders = rows.map((r) => r.habit.sortOrder).toList();
    expect(orders.toSet().length, orders.length);
  });
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/data/habit_dao_test.dart
```
Expected: FAIL — `reorderHabits` undefined; the integrity test fails because `createHabit` uses `existing.length` (D would get sortOrder 2, colliding with C).

- [ ] **Step 3: Edit `lib/data/habit_dao.dart`**

Replace the existing `createHabit` method:

```dart
  Future<int> createHabit({required String name, required int color}) async {
    final existing = await select(habits).get();
    return into(habits).insert(HabitsCompanion.insert(
      name: name,
      color: color,
      sortOrder: existing.length,
      createdAt: DateTime.now(),
    ));
  }
```

with:

```dart
  Future<int> createHabit({required String name, required int color}) async {
    final existing = await select(habits).get();
    final nextOrder = existing.isEmpty
        ? 0
        : existing.map((h) => h.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    return into(habits).insert(HabitsCompanion.insert(
      name: name,
      color: color,
      sortOrder: nextOrder,
      createdAt: DateTime.now(),
    ));
  }
```

And add this method after `renameHabit`:

```dart
  /// Persists a new ordering: sets each habit's sortOrder to its index in
  /// [orderedIds], in a single transaction.
  Future<void> reorderHabits(List<int> orderedIds) async {
    await transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (update(habits)..where((h) => h.id.equals(orderedIds[i])))
            .write(HabitsCompanion(sortOrder: Value(i)));
      }
    });
  }
```

- [ ] **Step 4: Run to verify it passes + full suite + analyze**

```bash
flutter test test/data/habit_dao_test.dart
flutter analyze
flutter test
```
Expected: DAO tests pass (existing + 2 new); analyze clean; full suite green. (Existing tests that relied on `createHabit`'s sortOrder being `0,1,2…` for fresh sequential creates still hold — with no deletes, `max+1` equals `count`.)

- [ ] **Step 5: Commit**

```bash
git add lib/data/habit_dao.dart test/data/habit_dao_test.dart
git commit -m "feat(data): add reorderHabits; fix createHabit sortOrder to max+1"
```

---

### Task 3: Home `ReorderableListView` + drag handle

**Files:**
- Modify: `lib/ui/habit_list/habit_list_screen.dart`
- Test: `test/ui/habit_list_screen_test.dart`

- [ ] **Step 1: Add failing tests** — append inside `main()` in `test/ui/habit_list_screen_test.dart` (the file already has `_app`, the drift/database imports, and pumps `HabitListScreen`):

```dart
  testWidgets('home is a reorderable list with a drag handle per habit',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.habitDao.createHabit(name: 'Read', color: 0xFF009688);
    await db.habitDao.createHabit(name: 'Meditate', color: 0xFF673AB7);
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
  });
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/ui/habit_list_screen_test.dart
```
Expected: FAIL — the home still uses a plain `ListView` (no `ReorderableListView`/`drag_handle`).

- [ ] **Step 3: Replace `lib/ui/habit_list/habit_list_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dates.dart';
import '../../domain/reorder.dart';
import '../../state/habit_providers.dart';
import '../habit_detail/habit_detail_screen.dart';
import '../settings/settings_screen.dart';
import '../widgets/day_strip.dart';
import '../widgets/habit_dialogs.dart';

class HabitListScreen extends ConsumerWidget {
  const HabitListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(habitSummariesProvider);
    return Scaffold(
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
          final dao = ref.read(habitDaoProvider);
          return ReorderableListView(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.symmetric(vertical: 6),
            // Flutter 3.44 deprecates onReorder in favour of onReorderItem,
            // which passes an already-adjusted newIndex (no manual decrement).
            // reorderedIds therefore does a plain move (see Task 1's note).
            onReorderItem: (oldIndex, newIndex) {
              final ids = [for (final it in items) it.habit.id];
              dao.reorderHabits(reorderedIds(ids, oldIndex, newIndex));
            },
            children: [
              for (var i = 0; i < items.length; i++)
                _HabitCard(
                  key: ValueKey('habit-${items[i].habit.id}'),
                  item: items[i],
                  index: i,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HabitCard extends ConsumerWidget {
  const _HabitCard({super.key, required this.item, required this.index});
  final HabitSummary item;
  final int index;

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
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.drag_handle,
                        key: ValueKey('drag-handle-${item.habit.id}'),
                        color: Theme.of(context).disabledColor,
                      ),
                    ),
                  ),
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

- [ ] **Step 4: Run the home tests + full suite + analyze**

```bash
flutter test test/ui/habit_list_screen_test.dart
flutter analyze
flutter test
```
Expected: the new reorder test passes, AND the existing home tests (add habit, check-off bumps streak, two habits with independent check controls, tapping a card opens detail) still pass — `Checkbox`, `Streak: N`, the habit-name, and `DayStrip` are all unchanged. Analyze clean; full suite green.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/habit_list/habit_list_screen.dart test/ui/habit_list_screen_test.dart
git commit -m "feat(ui): drag-to-reorder home list via per-card handle"
```

---

### Task 4: Final verification

No code changes.

- [ ] **Step 1: Analyze + full suite**

```bash
flutter analyze
flutter test
```
Expected: `No issues found!`; all tests pass (domain reorder, dao reorder/createHabit integrity, ui reorderable list, plus all prior suites).

- [ ] **Step 2: Confirm clean tree + branch**

```bash
git status
git branch --show-current   # expect feat/reorder-habits, NOT detached
git log --oneline -4 | cat
```
Expected: clean tree; on `feat/reorder-habits`; the 3 implementation commits present.

The merged `integration_test/critical_flow_test.dart` is unaffected: the home is now a `ReorderableListView` but still contains the `Checkbox`, `Streak: N` text, and habit-name text the test asserts (those finders don't depend on the list type). The actual drag-and-drop gesture is verified on device, not in a widget test.

---

## Self-review notes

- **Spec coverage:**
  - §1 interaction (ReorderableListView, `buildDefaultDragHandles: false`, per-card key + trailing `ReorderableDragStartListener` handle, drag from handle only, onReorder → reorderedIds → reorderHabits, stream-authoritative): Task 1 (`reorderedIds`), Task 3 (screen).
  - §2 persistence + integrity (`reorderHabits` transactional sortOrder=index; `createHabit` max+1): Task 2.
  - §3 architecture (pure reorder.dart, DAO methods, screen wiring): Tasks 1–3.
  - §4 testing (pure reorderedIds cases; DAO reorder + integrity; widget reorderable+handles; existing tests + integration test hold; drag device-verified): Tasks 1, 2, 3, 4.
  - §5 out-of-scope (no auto-sort/folders/drag-delete): none added.
- **Placeholder scan:** none.
- **Type/name consistency:** `reorderedIds(List<int>, int, int) -> List<int>` (Task 1) called in Task 3; `reorderHabits(List<int>)` (Task 2) called in Task 3; `_HabitCard` gains `key` + `index` (Task 3) and is constructed with both; widget keys `habit-<id>` / `drag-handle-<id>` and `find.byIcon(Icons.drag_handle)` consistent between Task 3 code and its test; the `Checkbox` + `Streak: N` text preserved so the integration test stays valid.
- **Known judgment calls:** the screen holds no local ordering state — `onReorder` persists and the reactive stream re-emits the new order (local-first, single source of truth); the actual drag gesture is device-verified because driving `ReorderableListView` drags in a widget test is flaky; `createHabit`'s `max+1` equals the old `count` when there are no deletes, so prior sequential-order assumptions still hold.

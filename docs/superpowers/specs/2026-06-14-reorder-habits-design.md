---
title: "Habbits — reorder habits design"
date: 2026-06-14
status: approved
type: design
references:
  - docs/superpowers/specs/2026-06-13-habbits-mobile-local-first-design.md
---

# Habbits — reorder habits

Let the user change the order of habits on the home screen by dragging a card via
a visible handle. Habits already have a `sortOrder` INTEGER column and the home
list renders ordered by it; this adds the UI + persistence to change it, and fixes
a latent `sortOrder` integrity bug. No schema change.

## 1. Interaction

The home list becomes a **`ReorderableListView`** with
`buildDefaultDragHandles: false`. Each habit card:

- has a unique `Key` (`ValueKey('habit-<id>')`), which `ReorderableListView`
  requires;
- carries a **trailing drag handle** (`Icons.drag_handle`, subtle / low-contrast)
  wrapped in a **`ReorderableDragStartListener(index: i, child: ...)`** so a drag
  starts **only** from the handle. Tapping the card still opens the detail screen
  and the check-off `Checkbox` still toggles — no gesture ambiguity.

On drop, `onReorderItem(oldIndex, newIndex)` computes the new ordering of habit ids
(via the pure `reorderedIds` helper) and calls `dao.reorderHabits(newOrder)`. The reactive
`watchHabitsWithDates` stream re-emits and the list re-renders in the new order —
the database is the single source of truth (no separate local ordering state).

## 2. Persistence and the `sortOrder` integrity fix

- **`HabitDao.reorderHabits(List<int> orderedIds)`** — in a single transaction,
  set each habit's `sortOrder` to its index in `orderedIds` (0, 1, 2, …). The home
  query already orders by `sortOrder`, so the next stream emission reflects the new
  order. Reorder therefore also compacts `sortOrder` back to a dense `0..n-1`.
- **Fix `createHabit`'s sortOrder.** It currently sets `sortOrder = existing.length`
  (the habit count), which collides after a delete: create A,B,C (orders 0,1,2),
  delete B, create D → count is 2 → D gets `sortOrder = 2`, colliding with C and
  producing an unstable order. Change it to **`max(existing sortOrder) + 1`** (0 for
  an empty list) so a new habit always lands at the end with a unique, monotonic
  order regardless of prior deletes.

## 3. Architecture

```
lib/domain/reorder.dart          # NEW (pure): List<int> reorderedIds(
                                 #   List<int> ids, int oldIndex, int newIndex)
                                 #   — plain immutable move (remove-at / insert-at)
                                 #   matching ReorderableListView's onReorderItem
                                 #   convention (newIndex already adjusted for the
                                 #   removed item). Unit-tested.
lib/data/habit_dao.dart          # + Future<void> reorderHabits(List<int> orderedIds)
                                 #   (transactional sortOrder = index);
                                 #   createHabit: sortOrder = max+1 instead of count.
lib/ui/habit_list/habit_list_screen.dart  # ListView -> ReorderableListView
                                 #   (buildDefaultDragHandles: false); each _HabitCard
                                 #   gets a ValueKey + an index + a trailing
                                 #   ReorderableDragStartListener drag handle;
                                 #   onReorderItem -> reorderedIds -> dao.reorderHabits.
```

**Decomposition.** `ReorderableListView`'s reorder callback is isolated behind the
pure `reorderedIds` helper, which is unit-tested. Flutter 3.44 deprecates the old
`onReorder` (which required the caller to decrement `newIndex` on downward moves) in
favour of `onReorderItem`, which reports an already-adjusted `newIndex`; `reorderedIds`
therefore does a plain remove-at / insert-at with no decrement. The DAO owns the
transactional persistence. The screen wires the handle and `onReorderItem`; it holds
no ordering state of its own (the stream is authoritative). No one-time hint is needed
— the visible handle is self-discoverable.

## 4. Testing

- **Pure `reorderedIds`**: move first-to-last, last-to-first, down past one
  neighbour, up by one, single-item list, and a no-mutation guard — encoding the
  `onReorderItem` convention (no decrement), so reintroducing a decrement fails a test.
- **DAO `reorderHabits`**: create three habits, reorder their ids, and assert
  `getHabitsWithDates` returns the new order with `sortOrder` values 0, 1, 2.
- **DAO integrity**: create A, B, C → delete B → create D → assert D lands at the
  end with a unique `sortOrder` (the old count-based code would have collided with
  C); `getHabitsWithDates` order is A, C, D.
- **Widget**: the home renders a `ReorderableListView` with one drag handle
  (`Icons.drag_handle`) per card; the existing home tests (add habit, check-off
  bumps streak, two habits, tap card → detail) still pass — the `Checkbox`,
  `Streak: N`, and habit-name finders are unchanged, so the merged
  `integration_test/critical_flow_test.dart` also still holds.
- The actual drag-and-drop gesture is verified on device (driving
  `ReorderableListView` drags in a widget test is flaky).

## 5. Out of scope

Auto-sort options (alphabetical, by streak, by completion); cross-grouping or
folders; reordering anything other than habits; drag-to-delete. Daily cadence and
all other product rules are unchanged.

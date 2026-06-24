---
status: draft
date: 2026-06-24
slug: detail-independent-load
summary: Detail screen loads its own habit via a single-habit repository watch instead of scanning the list view model's stream.
supersedes: null
superseded_by: null
pr: null
outcome: null
---

# Design: Detail screen loads independently of the list

## Summary

`HabitDetailViewModel.build` derives its state by linear-scanning the whole
`habitListViewModelProvider` stream for a matching id. This change gives the
detail view model its own data source — a single-habit repository watch
(`watchHabit(id)`) — and composes its summary through the existing
`HabitSummary.from` projection. The detail VM stops importing the list VM
entirely; its `build` becomes a `Stream<HabitSummary?>`, symmetric with the list
VM. The detail screen reads the resulting `AsyncValue` via `.valueOrNull`,
preserving its existing "null → spinner" branch unchanged.

## Motivation

`lib/ui/habit_detail/habit_detail_view_model.dart:14-21` today:

```dart
HabitSummary? build(int habitId) {
  final summaries = ref.watch(habitListViewModelProvider).value;
  if (summaries == null) return null;
  for (final s in summaries) {
    if (s.habit.id == habitId) return s;
  }
  return null;
}
```

Two couplings fall out of deriving one habit from the whole list (flagged as
candidate C in the 2026-06-24 architecture review):

1. **Temporal coupling.** The detail screen renders `null` (a spinner) until the
   *list* stream emits, even though it only needs one habit. Opening detail is
   gated on a query for N habits.
2. **Scope coupling.** Any change to the list VM's `map` — ordering, filtering, a
   new field — silently alters the detail screen's state, with no compile-time
   signal. The two screens are wired through a shared interface neither of them
   chose.

The smell is visible in the tests: every case in
`test/ui/habit_detail/habit_detail_view_model_test.dart` has to keep the list
stream alive by hand (`// keep list stream alive for the derived detail VM`) and
import `habit_list_view_model.dart`, purely to feed the thing under test.

This became cheap to fix once
[2026-06-24.01-habit-summary-factory](2026-06-24.01-habit-summary-factory/design.md)
gave the projection a home: detail can compose its own summary with the same
`HabitSummary.from` the list uses. The review sequenced C "after A" for exactly
this reason.

## Non-goals

- **Changing `HabitSummary` or the projection.** `HabitSummary.from` is reused
  as-is; this is purely about where the detail VM gets its row.
- **Absorbing the calendar builders.** Out of scope by
  [the scalar-only decision](../../decisions/2026-06-24-habit-summary-scalar-only.md);
  `buildHeatmap` / `recentDays` stay in the widgets.
- **Touching the list VM.** It keeps streaming the full list for the home screen;
  only the *detail*'s dependency on it is cut.

## Design

### 1. DAO — a single-habit watch

Add to `lib/data/services/database/habit_dao.dart`, mirroring the existing
`watchHabitsWithDates`:

```dart
/// Reactive stream of one habit with its completion dates, or null if no habit
/// has [id] (e.g. after deletion). Emits on any change to either table.
Stream<HabitWithDates?> watchHabitWithDates(int id) {
  final q = select(habits).join([
    leftOuterJoin(completions, completions.habitId.equalsExp(habits.id)),
  ])..where(habits.id.equals(id));
  return q.watch().map((rows) {
    final grouped = _group(rows);
    return grouped.isEmpty ? null : grouped.single;
  });
}
```

Reuses `_group` (the join → `HabitWithDates` collapse). No `orderBy` needed — at
most one habit. Returns `null` (not an empty/throwing single) when the habit is
absent, so a deletion observed mid-stream is a clean terminal value.

### 2. Repository — forward the watch

Add to `lib/data/repositories/habit_repository.dart`:

```dart
Stream<HabitWithDates?> watchHabit(int id) => _dao.watchHabitWithDates(id);
```

Keeps the view model on the repository seam; Drift stays out of `ui/`.

### 3. Detail VM — own the stream, drop the list import

`lib/ui/habit_detail/habit_detail_view_model.dart` — `build` becomes a stream
that composes through `HabitSummary.from`, watching `currentDayProvider` for the
single reactive `today`:

```dart
@override
Stream<HabitSummary?> build(int habitId) {
  final repo = ref.watch(habitRepositoryProvider);
  final today = ref.watch(currentDayProvider);
  return repo.watchHabit(habitId).map(
    (row) => row == null ? null : HabitSummary.from(row, today),
  );
}
```

The `import '../habit_list/habit_list_view_model.dart';` is removed. The command
methods (`toggle`, `editHabit`, `delete`, `setReminder`) are unchanged — they
already go straight to the repository. Generated `*.g.dart` regenerates (the
provider becomes a stream provider).

### 4. Detail screen — read the AsyncValue

`lib/ui/habit_detail/habit_detail_screen.dart:18` changes from a direct
`HabitSummary?` to `AsyncValue<HabitSummary?>`:

```dart
final summary = ref.watch(habitDetailViewModelProvider(habitId)).valueOrNull;
```

The existing `if (summary == null) { ...spinner... }` branch is untouched:
loading and "habit deleted" both surface as `null`, exactly as before. After a
delete, the stream emits `null` and the existing `Navigator.pop` still fires from
the delete handler.

## Testing

- **DAO** (`test/data/habit_dao_test.dart` or the nearest existing DAO test):
  `watchHabitWithDates` emits the habit with its dates, re-emits after a
  `toggleCompletion`, and emits `null` after `deleteHabit`.
- **Detail VM** (`test/ui/habit_detail/habit_detail_view_model_test.dart`):
  rewrite to build the detail VM with **no list VM in the container** — the
  `keep`-alive subscription and the `habit_list_view_model.dart` import are
  deleted. This is the coupling-removal proof. Assert: composes the summary for
  its id; re-emits on toggle; `null` for a missing id; re-emits when
  `currentDayProvider` advances. Reads switch from sync `?` to awaiting the
  detail provider's `AsyncValue`.
- **Detail screen** (`test/ui/habit_detail_screen_test.dart`): existing cases
  should pass with `.valueOrNull`; confirm the initial loading frame still shows
  the spinner and resolves.
- `just lint` + `just test` green; run `build_runner` first.

## Risk

- **Low–medium. Provider type change is the main blast radius.** `build` returns
  `Stream<HabitSummary?>` instead of `HabitSummary?`, so every reader gets an
  `AsyncValue`. Only two readers exist — the screen (`.valueOrNull`) and the VM
  test (awaits the value) — both updated here.
- **Deletion frame.** While on detail, deleting emits `null` → a spinner frame
  before `Navigator.pop`. Same net behavior as today (the list previously
  emitted without the habit → scan → `null` → spinner). No regression.
- **Mitigated by** the projection being unchanged: the *values* are identical to
  what the list produced; only the source moves. The DAO test pins the new query.

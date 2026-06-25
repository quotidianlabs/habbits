---
summary: Give the habit projection a home — a HabitSummary.from factory that owns the scalar composition, and one reactive today across all derived views.
---

# Design: Give the habit projection a home

## Summary

The composition that turns a habit's completion dates into its display scalars
(streak, done-today, completion %) currently lives inline in the home view
model, and the detail screen re-derives its calendar views against a *second*,
non-reactive `today`. This change moves the scalar composition into one place —
a factory constructor `HabitSummary.from(HabitWithDates row, DateTime today)` —
and threads a single reactive `today` (`currentDayProvider`) into every widget
that derives a view, deleting the two stray `dateOnly(DateTime.now())` calls.
Scalar-only: the parameterized calendar builders (`buildHeatmap`, `recentDays`)
stay pure functions in the widgets.

## Motivation

The "completion dates → habit projection" derivation has no single home, and
the friction shows up three ways:

1. **No module owns the scalar composition.** It is an inline `map` in
   `lib/ui/habit_list/habit_list_view_model.dart:21-32`. Nothing tests the
   composition directly; it is only exercised transitively through the
   view-model stream test and the two screen tests.
2. **Three divergent `today` sources.** The list view model reads the reactive
   `currentDayProvider` (`habit_list_view_model.dart:20`), but
   `habit_card.dart:19` and `habit_detail_screen.dart:28` each mint their own
   `dateOnly(DateTime.now())` for `DayStrip` / `buildHeatmap` / `RecentDaysList`.
   The detail heatmap therefore does **not** refresh at midnight (the value is
   captured once per build from the wall clock, not from the provider that ticks
   at local midnight and on resume), and can disagree with the list's notion of
   today during a timezone change.
3. **Normalization is a silent caller precondition.** `doneToday:
   row.dates.contains(today)` only works because both inputs happen to be
   day-only upstream; the check itself does no normalization.

The `domain/` layer already owns the leaf computations (`currentStreak`,
`completionPercent`) and the transfer object (`HabitWithDates`, which already
pairs the Drift `Habit` with its date set). What is missing is the one place
that composes them.

## Non-goals

- **Absorbing the calendar builders.** `buildHeatmap(weeks:)` and
  `recentDays(count:)` are parameterized by view-specific layout (`weeks` = 6 on
  detail; `count` = 14 on the strip, 30 on the recent-days list). They are not
  habit properties and stay pure functions called by the widgets.
- **Decoupling the detail view model from the list view model.** The detail VM
  continues to derive its summary by scanning the list VM's stream. Cutting that
  coupling needs a new single-habit repository watch and is tracked separately
  (the "detail loads independently" candidate).
- **Changing the `HabitSummary` field set.** Same four fields; only the
  construction path is new.

## Design

### 1. `HabitSummary.from` factory constructor

Add a factory to `lib/domain/models/habit_summary.dart` that owns the entire
scalar composition and the normalization invariant:

```dart
factory HabitSummary.from(HabitWithDates row, DateTime today) {
  final day = dateOnly(today);
  final completed = {for (final d in row.dates) dateOnly(d)};
  return HabitSummary(
    habit: row.habit,
    streak: currentStreak(completed, day),
    doneToday: completed.contains(day),
    completionPercent: completionPercent(completed, day),
    dates: completed,
  );
}
```

- **Scalar-only.** Returns the existing `HabitSummary` shape unchanged.
- **Normalizes internally** (Q5 decision). `today` and every entry of
  `row.dates` go through `dateOnly` once; the normalized set is stored in
  `dates`; `doneToday` is computed against normalized values. The interface
  carries the invariant — callers may pass any `DateTime`s. `currentStreak` /
  `completionPercent` re-normalizing the already-clean set is an idempotent
  no-op.
- `habit_summary.dart` gains imports of `dates.dart`, `streak.dart`,
  `completion_stats.dart`. It already imports the Drift `Habit` via
  `database.dart`, consistent with `HabitWithDates` in the same domain folder.

### 2. List view model calls the factory

`lib/ui/habit_list/habit_list_view_model.dart:21-32` — the inline
`HabitSummary(...)` map collapses to:

```dart
return repo.watchHabits().map(
  (rows) => [for (final row in rows) HabitSummary.from(row, today)],
);
```

`today` still comes from `ref.watch(currentDayProvider)`.

### 3. One reactive `today` in the widgets

Delete both stray wall-clock reads and watch the provider instead:

- `lib/ui/habit_list/widgets/habit_card.dart:19` — replace
  `final today = dateOnly(DateTime.now());` with
  `final today = ref.watch(currentDayProvider);` (already a `ConsumerWidget`).
- `lib/ui/habit_detail/habit_detail_screen.dart:28` — same replacement (already
  a `ConsumerWidget`); `buildHeatmap` and `RecentDaysList` then receive the
  reactive `today`.

After this, every derived view — list scalars, card strip, detail heatmap and
recent-days — reads the single `today` that ticks at local midnight and
refreshes on resume.

## Testing

- **New `test/domain/habit_summary_test.dart`** (pure; no Riverpod, no DB). The
  new home for the composition cases: assert streak / `doneToday` /
  `completionPercent` together from `HabitWithDates` fixtures, and the
  normalization contract from §1 — pass `DateTime`s carrying time-of-day and a
  non-normalized `today`, assert correct `doneToday` and a day-only `dates` set.
- **`test/ui/habit_list/habit_list_view_model_test.dart`** thins to wiring and
  reactivity: repo → factory → summaries stream, and re-emission on
  `currentDayProvider` change. Fine-grained streak/percentage edge cases move to
  the pure test.
- **Screen tests** (`habit_card`, `habit_detail`) gain one case: a
  `currentDayProvider` override advancing past midnight re-renders the
  heatmap / strip — locking the no-drift win so it cannot silently regress.
- `just lint` and `just test` green.

## Risk

- **Low. Behaviour-preserving for the list.** The list already derived `today`
  from `currentDayProvider`; the factory produces the same scalars. The pure
  test plus the existing stream test guard the composition.
- **Card/detail now rebuild at midnight.** Switching the card strip and detail
  heatmap from a captured wall-clock value to `currentDayProvider` makes them
  rebuild when the day ticks — intended, and the mechanism the home list already
  uses. The new midnight-advance screen test confirms it.
- **`architecture/streaks-and-stats.md` promotion.** The code map references the
  inline derivation and the "today" behaviour; the implementing PR updates that
  prose in the same diff (the convention's hand-promotion step).

---
status: shipped
date: 2026-06-24
slug: toggle-today-anchor
summary: Anchor toggleToday on currentDayProvider instead of the wall clock, so the home check-off writes the day the UI displays.
supersedes: null
superseded_by: null
pr: null
outcome: |
  toggleToday now writes ref.read(currentDayProvider) instead of
  dateOnly(DateTime.now()); the now-unused dates.dart import dropped from the
  view model. Strengthened the home VM test to pin currentDayProvider to a day
  far from the wall clock and assert the completion lands there (red against the
  old code: it wrote the wall-clock day). Audit confirmed this was the only
  wall-clock day-read on a write path. just lint clean; just test 165 green.
---

# Change: Anchor toggleToday on currentDayProvider

**Lane:** lightweight — one view-model line + its test, plus the truth-home
sentence in `streaks-and-stats.md`. No new file, no public-API change.

## Goal

The home check-off (`HabitListViewModel.toggleToday`) recomputes "today" from
`dateOnly(DateTime.now())`, independently of `currentDayProvider` — the single
live "today" that every *rendered* view derives from since
[2026-06-24.01-habit-summary-factory](2026-06-24.01-habit-summary-factory/design.md).
Any moment the provider and the wall clock disagree (the midnight-boundary
window before the ticker's timer fires, app left foregrounded), the strip shows
day N as today but the tap writes day N+1: the highlighted cell doesn't flip and
an unseen day gets the completion. Align the write path with the read path.

## Approach

`toggleToday` resolves the date from the provider the UI already shows, dropping
the independent wall-clock read:

```dart
Future<void> toggleToday(int habitId) => ref
    .read(habitRepositoryProvider)
    .toggleCompletion(habitId, ref.read(currentDayProvider));
```

`currentDayProvider`'s state is already date-only (built from
`dateOnly(DateTime.now())`), so the `dateOnly` wrap drops out. The view model
already `ref.watch`es this provider in `build()`, so the dependency exists; this
just makes read and write agree. No behavior change on the common path (provider
== wall-clock day normally) — it only closes the boundary window.

The detail screen is already correct: it passes the tapped `date` (sourced from
`currentDayProvider`) into `toggle(date)`, so it is untouched.

**Truth home:** `architecture/streaks-and-stats.md:30-36` currently documents the
divergence as intentional ("action-time writes (`toggleToday`) use real
`DateTime.now()` directly and are unaffected"). The implementing PR rewrites that
clause to state that `toggleToday` also derives "today" from `currentDayProvider`,
so no UI path reads the wall clock.

## Audit: other `DateTime.now()` reads (all correct, left as-is)

Swept `lib/` for wall-clock day-reads on write paths. `toggleToday` is the only
offender; the rest are correct by design and stay:

| Site | Purpose | Why it stays |
|------|---------|--------------|
| `current_day.dart:17,22,52` | the source of truth + midnight ticker | reading the clock *is* its job |
| `reminder_coordinator.dart:105` | `computeReminderSchedule(enabled, now)` | needs the real **instant** incl. time-of-day; date-only would break scheduling |
| `backup_repository.dart:24` | backup filename + metadata timestamp | needs the real instant; also data-layer, no UI-provider access |
| `habit_dao.dart:24,88,153` | `createdAt` instants | data-layer creation timestamps |

## Files

- `lib/ui/habit_list/habit_list_view_model.dart` — `toggleToday` reads
  `currentDayProvider` instead of `dateOnly(DateTime.now())`.
- `test/ui/habit_list/habit_list_view_model_test.dart` — strengthen the
  `toggleToday flips today` test: override `currentDayProvider` to a fixed day
  (reuse the existing `_FixedCurrentDay` helper) and assert the completion lands
  on the overridden day, not the wall-clock day. Fails against current code.
- `architecture/streaks-and-stats.md` — rewrite the lines 30-36 clause about
  `toggleToday` using the wall clock.

## Verification

- [x] Failing test first — pinning `currentDayProvider` to `2030-01-01`,
  `toggleToday` wrote the wall-clock day (`Set:[2026-06-24]`), red as expected.
- [x] Apply the one-line view-model change (+ drop the now-unused `dates.dart`).
- [x] `flutter test test/ui/habit_list/habit_list_view_model_test.dart` passes.
- [x] `just test` green (165); `just lint` clean.

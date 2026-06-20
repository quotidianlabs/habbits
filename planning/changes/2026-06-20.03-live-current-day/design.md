---
status: draft
date: 2026-06-20
slug: live-current-day
summary: Recompute "today" on a live day-boundary signal so the home list doesn't go stale across midnight.
supersedes: null
superseded_by: null
pr: null
outcome: null
---

# Design: Anchor "today" to a live day-boundary signal

## Summary

The home list derives `streak`, `doneToday`, and `completionPercent` against a
`today` value that is only recomputed when the Drift stream re-emits (i.e. on a
DB write). An app left open or resumed across local midnight therefore keeps
showing the previous day's state. This change introduces a `currentDay` provider
that ticks at local midnight (and refreshes on app resume) and has the home view
model read `today` from it, so a day rollover recomputes the displayed values.

## Motivation

From the [2026-06-20 hardening audit](../../audits/2026-06-20-hardening-audit.md)
(item #4, High/Medium), adversarially confirmed: `habit_list_view_model.dart:20`
computes `today = dateOnly(DateTime.now())` inside the `repo.watchHabits().map(...)`
callback. `HabitDao.watchHabitsWithDates` only emits on a change to the
habits/completions tables, and nothing else recomputes `today` — there is no
midnight timer and the only `AppLifecycleListener` (the reminder coordinator)
doesn't refresh the list. So across midnight with no DB write, `doneToday`,
`currentStreak`, and `completionPercent` all stay anchored to the prior calendar
day until the next interaction.

This is a *display* staleness only: `toggleToday` computes `dateOnly(DateTime.now())`
fresh at tap time, so it always writes the real today. The bug is that the card
can be rendered as if it were still yesterday.

## Non-goals

- Changing `toggleToday` / the detail screen's toggle. Both already use real `now`
  at action time and are correct.
- A global "clock" abstraction for the whole app. Only the displayed day anchor
  needs to be live; the new provider is scoped to that.
- Reworking how the reminder coordinator resyncs (separate audit item #5).

## Design

### 1. `nextLocalMidnight` pure helper (`dates.dart`)

```dart
/// Local midnight of the day after [now] (strictly after [now]). DST-safe via
/// calendar-date construction.
DateTime nextLocalMidnight(DateTime now) =>
    DateTime(now.year, now.month, now.day + 1);
```

Date construction (not `Duration`) keeps it correct across month/year ends and
DST transitions, matching the rest of `dates.dart`.

### 2. `currentDayProvider` (`lib/ui/core/current_day.dart`)

A keep-alive Riverpod `Notifier<DateTime>` that returns `dateOnly(DateTime.now())`
and keeps it live:

```dart
@Riverpod(keepAlive: true)
class CurrentDay extends _$CurrentDay {
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  @override
  DateTime build() {
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    ref.onDispose(() {
      _timer?.cancel();
      _lifecycle?.dispose();
    });
    _arm();
    return dateOnly(DateTime.now());
  }

  void _arm() {
    _timer?.cancel();
    final now = DateTime.now();
    _timer = Timer(nextLocalMidnight(now).difference(now), () {
      _refresh();
      _arm();
    });
  }

  void _refresh() {
    final today = dateOnly(DateTime.now());
    if (today != state) state = today; // no-op emit if the day hasn't changed
  }
}
```

- The **timer** covers the app sitting open in the foreground across midnight.
- The **`onResume` refresh** corrects immediately when the app returns from the
  background (and the late-firing backgrounded timer re-arms from the new now).
- `_refresh` only writes when the day actually changed, so resume on the same day
  is a no-op (no spurious list rebuild).

`current_day.dart` lives in `ui/core/` and may import Flutter (`AppLifecycleListener`),
consistent with the layer rules.

### 3. Home view model reads the provider

`HabitListViewModel.build()` swaps the inline `dateOnly(DateTime.now())` for
`ref.watch(currentDayProvider)`:

```dart
Stream<List<HabitSummary>> build() {
  final repo = ref.watch(habitRepositoryProvider);
  final today = ref.watch(currentDayProvider);
  return repo.watchHabits().map((rows) { /* …uses `today`… */ });
}
```

When the day ticks, the provider's state changes, the view model rebuilds,
re-subscribes to `watchHabits()` (which re-emits current data immediately), and
recomputes every summary for the new day. Riverpod retains the previous
`AsyncValue` data during the brief reload, so there is no visible flicker. The
detail view model derives from the list view model, so it follows automatically.

## Testing

- **`dates_test.dart`**: `nextLocalMidnight` returns the next day's 00:00, across
  a month end and a year end.
- **`habit_list_view_model_test.dart`**: override `currentDayProvider` (a tiny
  subclass returning a fixed day, bypassing the timer) and assert `doneToday`
  reflects the overridden day — true when a completion sits on it, false when the
  overridden day advances past it. This proves the view model anchors on the
  provider rather than wall-clock `now`.
- The timer/lifecycle wiring is thin glue over the tested pure helper; it is not
  unit-tested directly (a real `Timer` is non-deterministic in `flutter test`).

## Risk

- **Low.** The provider is additive; the view model change is a one-line swap with
  the existing suite as a regression guard. `keepAlive` plus `ref.onDispose`
  cleanup avoids a leaked timer/listener.
- A daily re-subscribe to `watchHabits()` is negligible and Drift re-emits
  current data synchronously on subscribe.

## Architecture promotion

Update [`architecture/streaks-and-stats.md`](../../../architecture/streaks-and-stats.md)
in the implementing PR: note that the home list's `today` is a live value from
`currentDayProvider` (ticks at local midnight, refreshes on resume), so streak /
completion-% / done-today stay correct across a day boundary without a DB write.

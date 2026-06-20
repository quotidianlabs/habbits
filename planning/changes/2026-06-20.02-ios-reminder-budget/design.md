---
status: shipped
date: 2026-06-20
slug: ios-reminder-budget
summary: Cap the reminder schedule at the iOS 64-notification budget and warn in Settings when habits exceed it.
supersedes: null
superseded_by: null
pr: 14
outcome: |
  computeReminderSchedule now generates all candidates, sorts by fire time, and
  truncates to kIosNotificationBudget (64) — the soonest reminders win, the OS
  no longer silently drops the tail. Settings shows an over-budget warning above
  the threshold. Closes audit item #3. +4 tests (141 total), lint clean.
---

# Design: Cap the reminder schedule at the iOS notification budget

## Summary

`computeReminderSchedule` is supposed to keep the total number of scheduled
notifications under iOS's 64-pending-notification cap, but its day-budget math
(`(iosBudget ~/ enabled.length).clamp(1, maxBuffer)`) has a lower clamp of `1`
that defeats the cap once there are more reminder-enabled habits than the budget:
65 habits each still emit one reminder → 65 notifications, and iOS silently drops
the tail. An arbitrary subset of habits then never fires.

This change makes the cap real by generating all candidate reminders and keeping
the **soonest `iosBudget`** of them, and surfaces a **Settings warning** when the
reminder-enabled habit count exceeds the budget (the regime where some habit is
guaranteed to get zero reminders).

## Motivation

From the [2026-06-20 hardening audit](../../audits/2026-06-20-hardening-audit.md)
(item #3, High), confirmed by adversarial verification:
`reminder_schedule.dart:38` computes `days = (iosBudget ~/ enabled.length).clamp(1, maxBuffer)`.
When `enabled.length > iosBudget` the integer division is `0`, the `.clamp(1, …)`
forces it back to `1`, and the loop emits `enabled.length` reminders total —
exceeding the 64-notification cap the budget logic exists to respect. iOS keeps
the first 64 and drops the rest, so habits past the cap silently never notify.

## Non-goals

- Platform-gating the cap. Android has no 64-notification limit, but the cap lives
  in the pure `computeReminderSchedule` domain function, which has no platform
  knowledge; keeping it universal is simpler and safe (64 daily reminders is
  already generous). The warning copy is therefore platform-neutral and does not
  name iOS.
- A proactive warning at the per-habit detail screen when a user enables the 65th
  reminder. Possible follow-up; the Settings surface was the chosen scope.
- Changing the per-habit buffer window or the done-today / time-passed skip rules.

## Design

### 1. Chronological cap in `computeReminderSchedule`

Replace the day-budget split with: generate every habit's candidate reminders
across the full `maxBuffer` window (unchanged per-day rules — skip today if the
habit is done or its time has passed), then sort all candidates by fire time and
keep the soonest `iosBudget`.

```dart
const int kIosNotificationBudget = 64;

List<ScheduledReminder> computeReminderSchedule(
  List<ReminderHabit> enabled,
  DateTime now, {
  int maxBuffer = 14,
  int iosBudget = kIosNotificationBudget,
}) {
  if (enabled.isEmpty) return const [];
  final all = <ScheduledReminder>[];
  for (final h in enabled) {
    final parts = h.time.split(':');
    final hh = int.parse(parts[0]);
    final mm = int.parse(parts[1]);
    for (var d = 0; d < maxBuffer; d++) {
      final when = DateTime(now.year, now.month, now.day + d, hh, mm);
      if (d == 0) {
        if (h.doneToday) continue; // already done today
        if (!when.isAfter(now)) continue; // time already passed today
      }
      all.add(ScheduledReminder(habitId: h.id, habitName: h.name, when: when));
    }
  }
  // Cap at the iOS pending-notification budget by keeping the soonest fire
  // times, so the most imminent reminders across all habits win the scarce
  // slots. Starved habits roll into the window on the next resync.
  all.sort((a, b) => a.when.compareTo(b.when));
  return all.length <= iosBudget ? all : all.sublist(0, iosBudget);
}
```

`kIosNotificationBudget` becomes the single source of truth for the cap, used both
as the default param here and as the Settings warning threshold.

**Behavior preservation.** For `enabled.length <= iosBudget` the result set is
identical to today's (proven by the existing tests staying green): e.g. 8 habits ×
14 candidates = 112, soonest 64 = days 0–7 × 8 habits = exactly 8 per habit. The
cut lands on a whole-day boundary (64 = 8×8), so the (non-stable) sort can't make
it nondeterministic. A single habit still gets its 14-day runway; done-today and
time-passed skips are unchanged. The only difference is ordering within the
returned list (now chronological rather than grouped-by-habit), which is
immaterial: `syncSchedule` assigns positional IDs and cancels-all before every
reschedule.

**Over-budget behavior.** For `enabled.length > iosBudget`, total candidates are
truncated to exactly `iosBudget`, so iOS never silently drops anything. Fire-time
ties break by position in `enabled` (Dart's sort is not stable, so this is an
explicit secondary key), making the kept set a deterministic function of caller
ordering. The coordinator passes habits in stable `sortOrder`, so the same habits
keep their reminders across resyncs rather than churning. When the cap falls
mid-day the habits earliest in order keep the extra last-day slot (an uneven but
deterministic tail) — above the cap *someone* must lose, and the schedule is fully
recomputed on each resync.

### 2. Settings warning

A habit is guaranteed zero reminders exactly when
`reminderEnabledCount > kIosNotificationBudget` (at or below the budget every
enabled habit always gets at least its near-term reminders). Add a `Consumer` to
the Settings `ListView` that watches `habitListViewModelProvider`, counts habits
with a non-null `reminderTime`, and renders a warning tile only above the
threshold:

```dart
Consumer(
  builder: (context, ref, _) {
    final count = (ref.watch(habitListViewModelProvider).value ?? const [])
        .where((s) => s.habit.reminderTime != null)
        .length;
    if (count <= kIosNotificationBudget) return const SizedBox.shrink();
    return ListTile(
      key: const Key('reminder-budget-warning'),
      leading: Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.error),
      title: Text(l10n.reminderLimitTitle),
      subtitle: Text(l10n.reminderLimitBody(kIosNotificationBudget)),
    );
  },
),
```

Placed as the first child of the `ListView` so it is visible on open. Below the
threshold it collapses to a zero-size box (no empty tile).

### 3. i18n

Two new ARB keys in `app_en.arb` (template) and `app_ru.arb`:

- `reminderLimitTitle` — "Too many reminders" / "Слишком много напоминаний"
- `reminderLimitBody` — `{count}` int placeholder, phrased with "no more than
  {count}" / "не более {count} напоминаний" so the number is genitive-governed and
  needs no ICU plural:
  - EN: "No more than {count} reminders can be scheduled at once, so some habits
    won't notify. Turn off reminders on a few habits."
  - RU: "Одновременно можно запланировать не более {count} напоминаний, поэтому
    часть привычек не будет уведомлять. Отключите напоминания у нескольких
    привычек."

## Testing

- **Domain** (`reminder_schedule_test.dart`): existing 6 tests stay green
  (behavior preservation). Add overflow tests using the injectable `iosBudget` /
  `maxBuffer` so no 65-habit fixture is needed:
  - `enabled.length > iosBudget` → result length `== iosBudget` (never exceeds).
  - With distinct future times and `maxBuffer: 1`, the kept reminders are the
    soonest `iosBudget` (assert the surviving habit ids by fire time).
- **Settings** (`settings_screen_test.dart`): with ≤ budget reminder-enabled
  habits the warning is absent; above the budget the `reminder-budget-warning`
  tile is present. Drive via an overridden `habitListViewModelProvider` and a
  small injected budget is not possible (UI uses the const), so the test seeds
  > 64 reminder-enabled summaries, or — to keep the fixture small — the test
  asserts against the const by constructing `kIosNotificationBudget + 1` minimal
  summaries.

## Risk

- **Low.** The domain change is a localized rewrite of one pure function with the
  existing test suite as a regression guard; the Settings change is additive and
  collapses to nothing below the threshold.
- Above the cap *some* habit must lose a reminder. The choice is deterministic
  (fire-time then `enabled` order) and self-correcting across resyncs, so it does
  not affect the core invariant (total ≤ `iosBudget`, soonest win).

## Architecture promotion

Update [`architecture/reminders.md`](../../../architecture/reminders.md) in the
implementing PR: replace the day-split description with the chronological-cap
behavior, state the hard `iosBudget` cap as an invariant, document the Settings
over-budget warning, and add a known-edge noting that beyond `kIosNotificationBudget`
reminder-enabled habits some habits cannot notify (an OS limit).

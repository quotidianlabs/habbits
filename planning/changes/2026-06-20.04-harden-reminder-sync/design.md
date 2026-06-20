---
status: shipped
date: 2026-06-20
slug: harden-reminder-sync
summary: Serialize ReminderCoordinator syncs, swallow plugin errors, and schedule reminders by wall-clock instant.
supersedes: null
superseded_by: null
pr: null
outcome: |
  _sync routed through a CoalescingRunner (no interleaved cancelAll+reschedule)
  and made best-effort; reminders scheduled by local wall-clock instant
  (DST-stable). First coordinator + notification-service tests. Closes audit #5,
  disputed #5b/#4-construction. +6 tests (151 total), lint clean.
---

# Design: Harden reminder sync

## Summary

Three reminder-scheduling robustness fixes from the
[2026-06-20 hardening audit](../../audits/2026-06-20-hardening-audit.md):
serialize `ReminderCoordinator._sync` so overlapping runs can't race on
`cancelAll()`, make it best-effort (a plugin failure no longer escapes as an
unhandled async error), and schedule each reminder by its wall-clock instant in
`tz.local` so the chosen `HH:mm` is preserved across DST. Backed by the first
tests for the coordinator and the schedule-instant construction.

## Motivation

- **#5 re-entrancy (Medium).** `_sync` fires from four sources (habit-list listen,
  locale listen, `onResume`, post-frame) with no guard. It is `async` and calls
  `cancelAll()` then schedules in a loop; two overlapping runs can interleave so
  the final OS notification set doesn't match state.
- **#5b no error handling (disputed).** `_sync` awaits `requestPermission()` /
  `syncSchedule()` with no `try/catch`; because it's invoked fire-and-forget, a
  platform-channel/plugin throw becomes an unhandled zone error. Reminder
  scheduling is best-effort and should degrade quietly.
- **#4 DST construction (disputed).** `notification_service.dart` schedules via
  `tz.TZDateTime.from(r.when, tz.local)`, which preserves the absolute *instant*
  of a VM-local `DateTime` rather than the intended wall-clock `HH:mm`. Building
  the instant directly in `tz.local` keeps the reminder at the chosen local time
  regardless of DST or any VM/`tz.local` zone mismatch. (Out of scope: resyncing
  when the device timezone changes — needs a platform listener; stays deferred.)

## Non-goals

- A platform timezone-change listener / resync (separate deferred item).
- Full coordinator coverage; tests here target the new guard, the error
  swallowing, and the schedule-instant construction.

## Design

### 1. Serialize + guard `_sync` (`reminder_coordinator.dart`)

Wrap the existing body in `_runSync()` and gate it behind an in-flight flag that
coalesces a single follow-up run, all inside a `try/catch`:

```dart
bool _syncing = false;
bool _pending = false;

Future<void> _sync() async {
  if (_syncing) {
    _pending = true; // coalesce: run once more after the current pass
    return;
  }
  _syncing = true;
  try {
    _pending = false;
    await _runSync();
    while (_pending && mounted) {
      _pending = false;
      await _runSync();
    }
  } catch (_) {
    // Best-effort scheduling: swallow plugin/platform failures.
  } finally {
    _syncing = false;
  }
}
```

`_runSync()` holds today's logic unchanged (read summaries → build `enabled` →
one-time permission → `syncSchedule`). This guarantees `cancelAll()`/schedule
sequences never interleave, while still reflecting the latest state via the
coalesced re-run.

### 2. Schedule by wall-clock instant (`notification_service.dart`)

```dart
// before: scheduledDate: tz.TZDateTime.from(r.when, tz.local),
scheduledDate: _instantFor(r.when),
```

with a testable helper:

```dart
@visibleForTesting
tz.TZDateTime instantFor(DateTime when) =>
    tz.TZDateTime(tz.local, when.year, when.month, when.day, when.hour, when.minute);
```

This constructs the local wall-clock time directly, so a habit set to 09:00 fires
at 09:00 local every day, including across a DST transition.

## Testing

- **`notification_service_test.dart` (new):** set a known DST zone
  (`tz.setLocalLocation(getLocation('America/New_York'))`) and assert `instantFor`
  yields the requested `HH:mm` in `tz.local` on both sides of the 2026 spring-
  forward (wall-clock preserved, `location == tz.local`).
- **`reminder_coordinator_test.dart` (new):** a `FakeNotificationService`
  (subclass recording `syncSchedule` calls, with a controllable in-flight
  `Completer`) mounted under `ReminderCoordinator` with an in-memory DB.
  - *Re-entrancy:* hold the first sync in-flight, trigger a second via a habit
    change, release; assert `syncSchedule` was never concurrent and a coalesced
    final sync ran.
  - *Error swallowing:* make `syncSchedule` throw; assert no exception escapes
    (the test completes and the widget stays mounted).

## Risk

- **Low.** The guard is local state; `_runSync` is the unchanged body. The
  schedule-instant change is a more-correct construction with the same type.
  Worst case for the coalescing loop is one extra `syncSchedule` pass, which is
  idempotent (cancel-all then reschedule).

## Architecture promotion

Update [`architecture/reminders.md`](../../../architecture/reminders.md): note
that `_sync` is serialized + best-effort, and that reminders are scheduled by
local wall-clock instant (DST-stable). Remove the resolved items from the Known
edges / deferred list (keeping the timezone-change-resync edge).

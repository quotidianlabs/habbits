---
status: shipped
date: 2026-06-24
slug: reminder-sync-controller
summary: Lift reminder-sync policy out of the coordinator widget into a plain-Dart ReminderSync controller, so the ordering, gate, and coalescing are unit-testable.
supersedes: null
superseded_by: null
pr: 25
outcome: |
  New lib/ui/core/reminder_sync.dart — a plain-Dart ReminderSync owning the
  CoalescingRunner, the once-only permission gate, and the sync()/onResume()
  sequences; collaborators injected as callbacks (the two mounted guards become
  an isActive() check). ReminderCoordinator shrank to a lifecycle adapter
  (-42 net lines) that builds the controller and forwards events. New pure
  reminder_sync_test.dart (8 cases: request-before-check ordering, gate-once,
  onResume order, coalescing, best-effort swallow, isActive guard, not-ready
  skip); the existing widget tests pass unchanged. just lint clean; just test
  178 green.
---

# Design: Lift reminder sync into a plain-Dart controller

## Summary

`_ReminderCoordinatorState` holds the entire reminder-scheduling *policy* inside
widget-lifecycle callbacks: the `CoalescingRunner`, the once-only
`_permissionAsked` gate, and two order-sensitive sequences (first-sync
permission prompt, resume-time timezone refresh). It is reachable only through
widget tests. This change extracts the policy into a plain-Dart `ReminderSync`
controller with two methods — `sync()` and `onResume()` — and collaborators
injected as plain callbacks. The `ReminderCoordinator` widget shrinks to a
lifecycle adapter that builds the controller and forwards events. The policy
becomes unit-testable; behavior is unchanged.

## Motivation

`lib/ui/core/reminder_coordinator.dart:23-112` mixes two concerns:

- **Wiring** (legitimately the widget's job): `AppLifecycleListener(onResume:)`,
  `ref.listenManual(habitListViewModelProvider)` + `localeControllerProvider`,
  and a post-frame initial sync.
- **Policy** (no reason to live in a widget): the `CoalescingRunner` that
  serializes `cancelAll()` + reschedule, the `_permissionAsked` gate, the
  first-sync sequence `requestPermission()` → `hasPermission()` → `report(...)`
  (order matters — on iOS a fresh "not determined" reads as disabled until the
  prompt resolves), and the resume sequence `refreshTimeZone()` → re-check
  permission → resync.

The order-sensitive sequences are the most valuable things to pin, yet today
they can only be exercised through `pumpAndSettle` and
`handleAppLifecycleStateChanged`. A bug that reordered request/check, or that
re-prompted on every sync, would slip past anything but a careful widget test.

This is the review's candidate B ("Worth exploring"); the win is testability,
not untangling a mess — `computeReminderSchedule` and `NotificationService` are
already extracted seams.

## Non-goals

- **Changing behavior.** Same sequences, same gate, same coalescing, same
  best-effort error swallowing. The existing widget tests pass untouched.
- **Moving the reactive wiring.** `ref.listen` and the lifecycle listener stay in
  the widget — reacting to providers/lifecycle is what a widget is for.
- **Touching `computeReminderSchedule` or `NotificationService`.** Already pure /
  already a seam.
- **Resolving the localized body without a `BuildContext`.** The widget keeps
  reading `AppLocalizations.of(context)` and passes it in as a closure.

## Design

### 1. `ReminderSync` — the policy controller

New `lib/ui/core/reminder_sync.dart`. Plain Dart: imports only
`domain/reminder_schedule.dart` (for `ReminderHabit` / `computeReminderSchedule`),
`data/services/notification_service.dart` (the service), and
`coalescing_runner.dart`. No Flutter widgets, no Riverpod.

```dart
class ReminderSync {
  ReminderSync({
    required NotificationService service,
    required List<ReminderHabit>? Function() readEnabledHabits,
    required String Function() readBody,
    required void Function(bool granted) reportPermission,
    required bool Function() isActive,
    DateTime Function() now = DateTime.now,
  });

  final _runner = CoalescingRunner();
  bool _permissionAsked = false;

  /// Coalesced, best-effort resync (post-frame / habit change / locale change).
  Future<void> sync() => _runner.run(_runSyncSafe);

  /// On resume: refresh the device timezone and re-check permission, then resync.
  Future<void> onResume() => _runner.run(() async {
    try {
      await service.refreshTimeZone();
      if (_permissionAsked) await _updatePermission();
    } catch (_) {/* best-effort; resync anyway */}
    await _runSyncSafe();
  });
}
```

`_runSyncSafe` wraps `_runSync` in a try/catch (swallow plugin failures).
`_runSync` mirrors today exactly:

1. `final enabled = readEnabledHabits();` — `null` means summaries not ready →
   return (no `cancelAll`). Otherwise it's the already-projected reminder list.
2. First sync with reminders and `!_permissionAsked`: set the gate, `await
   service.requestPermission()`, then `_updatePermission()`.
3. `if (!isActive()) return;` then `service.syncSchedule(
   computeReminderSchedule(enabled, now()), body: readBody())`.

`_updatePermission` = `final g = await service.hasPermission(); if
(!isActive()) return; reportPermission(g);` — the two `isActive()` checks stand
in for today's two `mounted` guards.

### 2. `ReminderCoordinator` — a lifecycle adapter

`_ReminderCoordinatorState` keeps only wiring. In `initState` it constructs the
controller, closures capturing `ref` / `context`:

```dart
_sync = ReminderSync(
  service: ref.read(notificationServiceProvider),
  readEnabledHabits: () {
    final summaries = ref.read(habitListViewModelProvider).value;
    if (summaries == null) return null;
    return [
      for (final s in summaries)
        if (s.habit.reminderTime != null)
          ReminderHabit(
            id: s.habit.id, name: s.habit.name,
            time: s.habit.reminderTime!, doneToday: s.doneToday,
          ),
    ];
  },
  readBody: () => AppLocalizations.of(context).reminderBody,
  reportPermission: (g) =>
      ref.read(notificationPermissionProvider.notifier).report(g),
  isActive: () => mounted,
);
ref.listenManual(habitListViewModelProvider, (_, _) => _sync.sync());
ref.listenManual(localeControllerProvider, (_, _) => _sync.sync());
_lifecycle = AppLifecycleListener(onResume: _sync.onResume);
WidgetsBinding.instance.addPostFrameCallback((_) => _sync.sync());
```

`dispose` still disposes `_lifecycle`. The `_runner` and `_permissionAsked`
fields, and the `_sync`/`_resyncWithTimeZone`/`_runSync`/`_updatePermission`
methods, are gone from the State. `build` returns `widget.child` unchanged.

The `summaries → ReminderHabit` projection stays in the widget closure, so
`ReminderSync` is a pure policy engine over `ReminderHabit` and never imports
`HabitSummary`.

## Testing

New `test/ui/core/reminder_sync_test.dart` — pure, no widget pumping. With a fake
`NotificationService` (reusing the shape already in
`reminder_coordinator_test.dart`) and plain closures:

- **Ordering:** first `sync()` with an enabled habit calls `requestPermission`
  before `hasPermission` (record call order), then `reportPermission` with the
  result.
- **Gate fires once:** a second `sync()` does not call `requestPermission` again.
- **Resume sequence:** `onResume()` calls `refreshTimeZone`, then (if asked)
  `hasPermission`, then `syncSchedule` — in that order.
- **Coalescing:** two overlapping `sync()` calls serialize into the expected
  number of `syncSchedule` invocations (no interleave).
- **Best-effort:** a `syncSchedule` that throws does not escape `sync()`.
- **isActive guard:** with `isActive: () => false`, a `sync()` after the await
  neither reports permission nor schedules.
- **Not-ready skip:** `readEnabledHabits: () => null` → no `syncSchedule`,
  no `cancelAll`.

The existing `reminder_coordinator_test.dart` widget tests stay as integration
coverage and should pass unchanged (behavior is identical).

`just lint` + `just test` green.

## Risk

- **Low. Behavior-preserving refactor.** The sequences, gate, coalescing, and
  error-swallowing are moved verbatim; the existing widget tests are the
  regression guard and are not modified.
- **The `isActive`/`mounted` edge.** The two guards must land at the same points
  (before the permission report; before reading body + scheduling) or a
  post-dispose async completion could touch a disposed widget. The unit test for
  the `isActive` guard plus the unchanged widget tests cover this.
- **Closure capture of `context`.** `readBody` captures `context`; it is only
  invoked after the `isActive()` guard, so it is never read post-dispose — same
  as today's `if (!mounted) return` before the body read.

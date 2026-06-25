---
summary: Warn when notification permission is denied, refresh the timezone on resume, and test removed-reminder cleanup.
---

# Design: Reminder resilience

## Summary

Three remaining reminder gaps from the
[2026-06-20 hardening audit](../../audits/2026-06-20-hardening-audit.md):
surface a Settings warning when notification permission is denied (so reminders
silently failing is visible), refresh `tz.local` on app resume (so reminders
follow the device after travel), and add a coordinator test that a removed
reminder drops out of the next schedule.

## Motivation

- **Permission denial (#7a).** `ReminderCoordinator._runSync` calls
  `requestPermission()` but ignores its result and proceeds to `syncSchedule`,
  which the OS silently drops when permission is denied — reminders never fire
  and the user gets no signal.
- **No resync on timezone change (disputed remainder).** `tz.local` is set once
  in `NotificationService.init()`; after travelling across zones, reminders stay
  on the old zone's wall-clock until a restart.
- **Cancel/reschedule coverage (#7b).** The behavior (cancel-all then reschedule)
  is correct but the "a removed/disabled reminder is gone after resync" seam is
  untested at the layer that matters.

## Non-goals

- A tappable "open system settings" button for the permission warning — needs a
  new dependency (`app_settings`/`permission_handler`); the hint alone is the
  scope. Deferred follow-up.
- A platform timezone-change broadcast listener for the app-foregrounded-across-a
  -zone-change case — resume covers the realistic "land and open" path; the
  broadcast-listener case stays deferred.
- A mock-method-channel test of the real `syncSchedule` plugin calls (fragile).

## Design

### 1. Permission status (`notification_service.dart` + a provider)

Add `Future<bool> hasPermission()` — a **check**, not a prompt:
`IOSFlutterLocalNotificationsPlugin.checkPermissions()?.isEnabled`, else
`AndroidFlutterLocalNotificationsPlugin.areNotificationsEnabled()`, defaulting to
`true` on an unknown platform (don't nag).

Add a keep-alive `notificationPermissionProvider` (`Notifier<bool?>`, `null` =
unknown). `_runSync` sets it after the (one-time) prompt and on each subsequent
sync/resume:

```dart
if (enabled.isNotEmpty) {
  if (!_permissionAsked) { _permissionAsked = true; await service.requestPermission(); }
  final granted = await service.hasPermission();
  if (!mounted) return;
  ref.read(notificationPermissionProvider.notifier).set(granted);
}
```

Settings keeps decoupled from the service: it watches the provider, which stays
`null` (no warning) when no coordinator is mounted — so existing Settings tests
are unaffected.

### 2. Settings "notifications off" warning

A `Consumer` tile (key `notifications-off-warning`) shown only when there is at
least one reminder-enabled habit **and** `notificationPermissionProvider == false`
(`null`/`true` → hidden). Mirrors the budget-warning tile; new ARB keys
`notificationsOffTitle` / `notificationsOffBody` (en/ru).

### 3. Timezone refresh on resume

Add `NotificationService.refreshTimeZone()` (`FlutterTimezone.getLocalTimezone()`
→ `tz.setLocalLocation`) and call it from `init()` (dedupe) and from the
coordinator's `onResume` before resyncing:

```dart
_lifecycle = AppLifecycleListener(onResume: _resyncWithTimeZone);
Future<void> _resyncWithTimeZone() => _runner.run(() async {
  try { await ref.read(notificationServiceProvider).refreshTimeZone(); } catch (_) {}
  await _runSyncSafe();
});
```

Refreshing only on resume (not every sync) avoids a platform call on every habit
toggle.

## Testing

- **Coordinator** (`reminder_coordinator_test.dart`): a `FakeNotificationService`
  gains `hasPermission` (configurable) + `refreshTimeZone` (records calls).
  - permission denied → `notificationPermissionProvider` becomes `false`.
  - a reminder removed (`setReminderTime(id, null)`) → next `syncSchedule`
    excludes it (cancel/reschedule seam).
  - resume (`handleAppLifecycleStateChanged` inactive→resumed) → `refreshTimeZone`
    is called.
- **Settings** (`settings_screen_test.dart`): override `notificationPermissionProvider`
  → with a reminder habit, `false` shows the warning, `true`/`null` hide it.

`tz.local` refresh content itself (platform channel) is verified by wiring, not a
unit test.

## Risk

- **Low.** Additive provider + tile + two service methods. The permission set is
  guarded by `mounted`; the warning is hidden unless explicitly denied.

## Architecture promotion

Update [`architecture/reminders.md`](../../../architecture/reminders.md):
permission status surfaced via `notificationPermissionProvider` + Settings
warning; `tz.local` refreshed on resume. Trim the resolved bits from `deferred.md`
(leaving the broadcast-listener and open-OS-settings follow-ups).

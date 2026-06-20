# Reminders

## Purpose

Fire a local on-device notification at each habit's chosen reminder time on days
the habit is not yet completed that day.

## Behavior

- A habit carries an optional reminder time stored as `'HH:mm'` in the
  `habits.reminder_time` TEXT column; `null` means reminders are off for that
  habit.
- When any habit or completion changes, and when the app returns to the
  foreground, the coordinator recomputes the full notification schedule and
  pushes it to the OS atomically (cancel-all then re-schedule).
- Today's slot is scheduled only if the habit is not done today **and** the
  reminder time is still in the future relative to the moment of sync. All
  future days within the buffer window are always scheduled.
- Each enabled habit produces candidate reminders across a 14-day window, and the
  full set is then hard-capped at the iOS 64-pending-notification budget by
  keeping the **soonest** fire times. A single habit gets a 14-day runway; 8
  habits get 8 days each; total pending notifications never exceeds 64. When more
  than 64 habits have reminders the most imminent 64 win and the rest get none
  until the next resync — see Known edges.
- The first time any reminder is enabled the coordinator calls
  `requestPermission()`; subsequent syncs skip the prompt.
- Tapping a notification opens the app to the home screen; there is no
  deep-link to a specific habit.
- Android uses inexact scheduling
  (`AndroidScheduleMode.inexactAllowWhileIdle`); reminders may fire a few
  minutes off, which is acceptable for daily habits.
- Notification times are scheduled as local-zone instants via the `timezone`
  package; the device's IANA zone is resolved once at init by `flutter_timezone`.

## Code map

- `lib/domain/reminder_schedule.dart` — `computeReminderSchedule(List<ReminderHabit> enabled, DateTime now, {int maxBuffer = 14, int iosBudget = kIosNotificationBudget}) → List<ScheduledReminder>`: pure function; expands each habit across the buffer window (done-today skip, time-passed skip), then sorts by fire time and truncates to `iosBudget`. No Flutter or plugin imports. `kIosNotificationBudget = 64` is the single source of truth for the cap, reused by the Settings warning.
- `lib/domain/reminder_schedule.dart:2` — `ReminderHabit` and `ScheduledReminder` value types consumed by the function and the service.
- `lib/data/services/notification_service.dart:13` — `NotificationService`: thin wrapper over `flutter_local_notifications`; exposes `init()`, `requestPermission()`, `syncSchedule(reminders, {body})`, and `cancelAll()`. All scheduling policy lives in `computeReminderSchedule`, not here.
- `lib/ui/core/reminder_coordinator.dart:12` — `ReminderCoordinator`: root-mounted `ConsumerStatefulWidget` that renders its `child` unchanged; the only widget that touches the notification service.

## Invariants

- Scheduling is derived, not stored. The coordinator calls `cancelAll()` then
  reschedules from scratch on every sync; it never reads back pending
  notification IDs from the OS or persists them. The schedule is fully
  recomputed from the current `habitListViewModelProvider`
  (`lib/ui/habit_list/habit_list_view_model.dart:17`) value.
- Notification IDs are positional integers assigned by index in the
  `syncSchedule` loop (`id: i`), not derived from habit IDs. Because the
  service always cancels all before re-scheduling, stale IDs cannot accumulate.
- A habit with no `reminderTime` produces no `ReminderHabit` and therefore no
  scheduled notifications.
- The total scheduled set never exceeds `kIosNotificationBudget` (64). Above the
  budget the soonest fire times are kept; the identity of dropped habits at the
  cut is arbitrary when reminder times tie.
- The Settings screen renders an over-budget warning
  (`lib/ui/settings/settings_screen.dart`, key `reminder-budget-warning`) when
  more than `kIosNotificationBudget` habits have reminders enabled — the exact
  threshold at which some habit is guaranteed zero reminders.
- Four events trigger a resync:
  - Initial render (`addPostFrameCallback`).
  - Every emission of `habitListViewModelProvider` (covers check-off, reminder
    edits, add, delete).
  - App resume via `AppLifecycleListener.onResume`.
  - Locale change via `localeControllerProvider` (keeps notification body text
    in the current language).
- Permission is requested at most once per app session (`_permissionAsked`
  guard); the request fires only when at least one habit has a reminder
  enabled.

## Known edges

- The Android notification channel name (`'Habit reminders'`) is hard-coded English; `NotificationService._channelName` (`lib/data/services/notification_service.dart:19`) is a `const` and is not localized.
- Beyond `kIosNotificationBudget` (64) reminder-enabled habits, some habits cannot notify at all — an OS limit on pending local notifications, not a bug. The schedule keeps the soonest 64 and Settings shows a warning. The cap is applied on all platforms (the pure domain function is platform-agnostic), so Android is capped at 64 too even though it has no such OS limit.

## History

Defined by: [2026-06-14.02-reminders](../planning/changes/archive/2026-06-14.02-reminders/design.md)

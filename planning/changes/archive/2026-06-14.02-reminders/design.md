---
status: shipped
date: 2026-06-14
slug: reminders
supersedes: null
superseded_by: null
pr: merged to main locally
outcome: Per-habit local-notification reminders (flutter_local_notifications + timezone).
---


# Habbits — local reminders

Per-habit daily reminders, fully on-device (no backend). Each habit can be given
an optional reminder time; on days the habit isn't done, the app nudges you. The
scheduling works by acting at foreground moments (data changes, app resume) rather
than at notification fire-time, so it behaves correctly within iOS/Android limits.

The `habits.reminder_time` TEXT column (nullable `'HH:mm'`) already exists from the
foundation: `null` = reminder off, a value = on at that time. No schema change.

## 1. Scheduling model

The whole behavior reduces to one rule: **schedule a notification for each upcoming
day a habit isn't done.** Future days can't be done yet, so in practice each enabled
habit gets a reminder for *today* (only if not already checked and the time hasn't
passed) plus the next several days.

- **Rolling buffer.** Per enabled habit, schedule one-shot local notifications for
  the next **N** days at its `HH:mm`.
- **Skip rule (per-habit).** A habit's reminder for a given day is suppressed iff
  that habit is completed on that day. Only checking off *that* habit suppresses it
  — opening the app does not. (Opening/resuming does trigger a resync, which then
  re-evaluates "done today".)
- **Today's slot** is scheduled only if the habit is not done today **and** `now`
  is before today's `HH:mm` (a time already passed today is not scheduled). All
  future days in the window are scheduled.
- **iOS 64 cap.** iOS allows at most 64 pending local notifications per app. The
  buffer length adapts: `N = min(14, floor(64 / enabledCount))` (with
  `enabledCount ≥ 1`). 1 habit → 14-day runway; 5 → 12 each; 8 → 8 each. Total
  scheduled stays ≤ 64.
- **Runway.** Reminders keep firing for up to N days even if the app is never
  opened; after that they go quiet until the app is reopened (which re-extends the
  buffer). N ≈ 8–14 days is a comfortable cushion.
- **Reschedule triggers** (both foreground, where Dart runs): (1) **every emission
  of the `watchHabitsWithDates` stream** — covers check-off, reminder edits, add,
  delete; (2) **app resume** — re-extends the runway and re-establishes after a
  device reboot (the stream alone does not emit on resume).
- **Android** uses inexact scheduling (`AndroidScheduleMode.inexactAllowWhileIdle`)
  so it needs no special exact-alarm permission; reminders may fire a few minutes
  off, which is fine for habits.
- **Time zone.** Notifications are scheduled as local-zone instants via the
  `timezone` package, with the device's IANA zone resolved by `flutter_timezone`.

## 2. Per-habit reminder UI

On the **habit detail screen**, a **Reminder** row:
- A trailing **switch** (on/off) and, when on, the time (e.g. `Reminder · 8:30 AM`).
- Toggling **on** opens a time picker (default `09:00`) and saves
  `reminder_time = 'HH:mm'`. Tapping the shown time re-opens the picker. Toggling
  **off** sets `reminder_time = null`.
- The **first time** any reminder is enabled, the app requests notification
  permission (iOS `requestPermissions`; Android 13+ `POST_NOTIFICATIONS`). If
  denied, the setting still saves, and a snackbar explains reminders need permission
  (grantable later in OS settings). The scheduler simply produces no visible
  notifications until permission is granted.

## 3. Notification content

- **Title:** the habit's name.
- **Body:** a gentle nudge (e.g. "Time to check in").
- **Tap:** opens the app to the home screen (no deep-link — per the earlier call).
- A single Android channel, `habit_reminders` ("Habit reminders").

## 4. Architecture

```
lib/domain/reminder_schedule.dart   # NEW (pure): the brains.
                                    #   class ReminderHabit { int id; String name;
                                    #     String time /* HH:mm */; bool doneToday; }
                                    #   class ScheduledReminder { int habitId;
                                    #     String habitName; DateTime when; }
                                    #   List<ScheduledReminder> computeReminderSchedule(
                                    #     List<ReminderHabit> enabled, DateTime now,
                                    #     {int maxBuffer = 14, int iosBudget = 64});
                                    #   Applies the budget split, skip-today, time-
                                    #   passed, and date/time expansion. Unit-tested.
lib/data/habit_dao.dart             # + Future<void> setReminderTime(int id, String? hhmm)
lib/services/notification_service.dart  # NEW: wraps flutter_local_notifications +
                                        #   timezone. init() (tz + channel), 
                                        #   requestPermission() -> bool,
                                        #   syncSchedule(List<ScheduledReminder>)
                                        #   (cancelAll + zonedSchedule each, inexact),
                                        #   cancelAll(). Plugin boundary.
lib/state/reminder_coordinator.dart # NEW: a root-mounted ConsumerStatefulWidget (or
                                    #   provider) that ref.listens habitSummaries +
                                    #   observes app lifecycle; on change/resume,
                                    #   maps enabled habits -> ReminderHabit, runs
                                    #   computeReminderSchedule(now), calls
                                    #   notificationService.syncSchedule.
lib/ui/habit_detail/...             # the Reminder row (switch + time picker)
main.dart                           # await notificationService.init() before runApp;
                                    #   mount the coordinator above the home so it
                                    #   runs regardless of the visible screen.
```

**Decomposition.** All the decision logic (which habits, which days, the 64-budget
split, skip-today, time-passed) lives in the pure `computeReminderSchedule` and is
unit-tested with no Flutter/plugins. `HabitSummary` already carries `habit`
(with `id`, `name`, `reminderTime`), `doneToday`, so the coordinator builds
`ReminderHabit`s straight from `habitSummariesProvider` — no new query.
`notification_service` is the thin, untested plugin boundary; the coordinator wires
the pure scheduler to it on the two triggers.

**Packages:** `flutter_local_notifications`, `timezone`, `flutter_timezone`.

## 5. Testing

- **Pure `computeReminderSchedule`** (the real coverage, table-driven):
  - only enabled habits (a `ReminderHabit` only exists for `reminder_time != null`)
    produce reminders.
  - today is skipped when the habit is done today, and when `now` is already past
    today's time; future days are always included.
  - buffer length `N = min(14, floor(64 / count))`; total scheduled ≤ 64 across
    multiple habits.
  - dates/times are correct (next N days at the parsed `HH:mm`, local).
  - zero enabled habits → empty schedule.
- **DAO:** `setReminderTime` persists a value and clears it to null.
- **UI (widget):** the Reminder row toggles on (opens picker, saves a time) and off
  (clears), and reflects the current value.
- **Plugin boundary** (`notification_service`) is verified on a device, not
  unit-tested. The coordinator's wiring is covered by injecting a fake
  notification sink in a focused test if practical; otherwise verified on device.

## 6. Risk & out of scope

- **Build-compat risk:** as with `file_picker`, `flutter_local_notifications` /
  `timezone` may need version pinning on the 4-day-old Flutter 3.44. Verify a
  release build **early** in implementation (a smoke build right after adding the
  packages), not at the end.
- **Out of scope:** notification actions (check-off from the notification) — a
  deliberate fast-follow once core reminders work on-device; multiple reminders per
  habit; snooze; deep-link to a specific habit; per-habit custom sounds; weekly/
  custom cadence (habits remain daily).

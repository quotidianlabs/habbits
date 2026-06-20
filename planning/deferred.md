# Deferred

Real-but-unscheduled items. Each has a revisit trigger. Promote one into a
change bundle when its trigger fires.

- **Android notification channel name not localized** —
  `NotificationService._channelName = 'Habit reminders'` is hard-coded English
  (no `BuildContext` at the `const` site). *Revisit when* notification copy is
  next touched.
- **`share_plus` iPad popover anchor** — `backup_repository.dart`'s
  `SharePlus...share` passes no `sharePositionOrigin`, which crashes on iPad.
  *Revisit when* iPad becomes a target.
- **`test/ui/` screen/widget tests not mirrored** into feature subfolders
  (e.g. `habit_list_screen_test.dart` sits flat, not under `test/ui/habit_list/`).
  *Revisit on* the next test-organization pass.
- **Codecov coverage upload** — `flutter test --coverage` + `codecov-action`,
  matching the sibling repos. *Revisit when* the CI sub-project lands.
- **Longest/best-streak metric** — show each habit's best-ever streak alongside
  the current streak; a natural extension of `streak.dart` / the stats surface
  (from the legacy product briefs). *Revisit when* streaks-and-stats next gains
  a feature.
- **Non-daily cadence** — habits with weekly or custom frequency rather than the
  current daily-only model; touches the completion data model and the
  streak/completion math (from the legacy product briefs). *Revisit when* a
  non-daily habit is actually needed.

## From the 2026-06-20 hardening audit

See [`audits/2026-06-20-hardening-audit.md`](audits/2026-06-20-hardening-audit.md).
Items 1, 2, 6 are being fixed in `changes/2026-06-20.01-harden-toggle-and-import`;
the rest are below.

- **Reminder coverage gaps (remainder)** (audit #7, Medium) — budget overflow,
  the schedule-instant construction, and `_sync` serialization/error handling are
  now tested; still untested: permission-denial handling and explicit
  cancel-then-reschedule ordering. *Revisit with* the next reminder change.
- **No resync on device timezone change** (audit, disputed remainder) —
  `tz.local` is set once at `init()`; travelling across zones leaves reminders on
  the old zone's wall-clock until the next sync. (The DST *construction* drift is
  fixed via `scheduledInstant`.) *Revisit when* a timezone-change reminder bug is
  reported. Fix: a platform timezone-change listener + `tz.setLocalLocation` +
  resync.

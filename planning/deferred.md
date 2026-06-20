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
- **Backup test-file naming inversion** — `test/domain/backup_test.dart` covers
  the pure codec while `backup_codec_test.dart` covers DB-backed `buildBackup`;
  the names are swapped. *Revisit when* either file is next edited.
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

- **iOS notification-budget overflow** (audit #3, High) —
  `reminder_schedule.dart:38` `(iosBudget ~/ len).clamp(1, …)` lets 65+ reminder
  habits schedule past iOS's 64-notification cap, silently dropping the tail.
  *Revisit when* reminders next gain a feature, or a user reports missed
  reminders with many habits.
- **"Today" goes stale across midnight** (audit #4, High/Medium) —
  `habit_list_view_model.dart:20` computes `today` only inside the Drift stream
  callback; an app left open overnight shows yesterday's state until the next DB
  write. Self-healing on next tap. *Revisit when* the habit-list view model is
  next touched. Fix: a `currentDay` provider that ticks at local midnight.
- **`ReminderCoordinator._sync` re-entrancy** (audit #5, Medium) —
  `reminder_coordinator.dart:41` is fired from 4 sources with no guard;
  overlapping runs race on `cancelAll()`. *Revisit when* reminder scheduling is
  next touched. Fix: serialize / debounce.
- **Reminder coverage gaps** (audit #7, Medium) — no tests for the budget
  overflow, `TZDateTime.from` DST conversion, cancel/reschedule sequencing,
  permission denial, or malformed-time parsing. *Revisit with* any reminder fix
  above.
- **Heatmap month label off by a column** (audit #8, Low) —
  `heatmap_grid.dart:42` labels by the column's Monday, not the column containing
  the 1st; a month starting Tue–Sun labels one column late. *Revisit when* the
  heatmap is next edited.
- **DST / timezone reminder drift** (audit, disputed) —
  `notification_service.dart:84` builds fire time via `TZDateTime.from` (preserves
  instant, not wall-clock); `tz.local` set once at `init()`. *Revisit when* a
  timezone/DST reminder bug is actually reported.
- **`_sync` has no `try/catch`** (audit, disputed) — a plugin failure becomes an
  unhandled async error. *Revisit with* the `_sync` re-entrancy fix.
- **`'Habbits backup'` share subject hard-coded English** (audit, disputed) —
  `backup_repository.dart:28` bypasses l10n; Russian users get an English subject.
  *Revisit when* backup or i18n copy is next touched.

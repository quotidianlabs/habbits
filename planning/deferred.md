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

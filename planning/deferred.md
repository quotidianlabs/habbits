# Deferred

Real-but-unscheduled items. Each has a revisit trigger. Promote one into a
change bundle when its trigger fires.

- **`architecture/` truth-home capability docs** — living, frontmatter-free
  capability docs at the repo root (habit tracking, streaks/stats, reminders,
  backup I/O, i18n, theming). *Revisit when* the next feature needs a stable
  capability contract to point at, or on the next docs pass.
- **Android notification channel name not localized** —
  `NotificationService._channelName = 'Habit reminders'` is hard-coded English
  (no `BuildContext` at the `const` site). *Revisit when* notification copy is
  next touched.
- **`share_plus` iPad popover anchor** — `backup_repository.dart`'s
  `SharePlus...share` passes no `sharePositionOrigin`, which crashes on iPad.
  *Revisit when* iPad becomes a target.
- **`TextEditingController` not disposed** in `habit_dialogs.dart`
  (pre-existing). *Revisit when* the dialogs move to a `StatefulWidget` or on a
  lint sweep.
- **Color picker in the create/edit dialog** — `habit_dialogs.dart` collects
  only the habit name; the color is defaulted in the view model. Add a color
  picker so the user can choose a habit's color on create/edit. *Revisit when*
  `habit_dialogs.dart` is next touched or on a UI polish pass.
- **Backup test-file naming inversion** — `test/domain/backup_test.dart` covers
  the pure codec while `backup_codec_test.dart` covers DB-backed `buildBackup`;
  the names are swapped. *Revisit when* either file is next edited.
- **`test/ui/` screen/widget tests not mirrored** into feature subfolders
  (e.g. `habit_list_screen_test.dart` sits flat, not under `test/ui/habit_list/`).
  *Revisit on* the next test-organization pass.
- **Codecov coverage upload** — `flutter test --coverage` + `codecov-action`,
  matching the sibling repos. *Revisit when* the CI sub-project lands.

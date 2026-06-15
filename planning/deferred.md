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
- **No dark theme** — `MaterialApp` sets `theme` only (`lib/main.dart:38`); with
  no `darkTheme`/`themeMode`, the light teal Material 3 palette renders regardless
  of device brightness, so the app has no dark mode. Add a dark `ThemeData` (and,
  if wanted, a theme-mode selector + persistence mirroring the locale store).
  *Revisit when* dark mode is requested or on a theming pass.
- **Heatmap/day-strip colors not dark-surface adaptive** — per-habit
  `Color(habit.color)` and inactive cells at `withValues(alpha: 0.15)`
  (`heatmap_grid.dart`, `day_strip.dart`) are drawn directly and assume a light
  surface. *Revisit with* dark-theme support (depends on it).
- **Backup test-file naming inversion** — `test/domain/backup_test.dart` covers
  the pure codec while `backup_codec_test.dart` covers DB-backed `buildBackup`;
  the names are swapped. *Revisit when* either file is next edited.
- **`test/ui/` screen/widget tests not mirrored** into feature subfolders
  (e.g. `habit_list_screen_test.dart` sits flat, not under `test/ui/habit_list/`).
  *Revisit on* the next test-organization pass.
- **Codecov coverage upload** — `flutter test --coverage` + `codecov-action`,
  matching the sibling repos. *Revisit when* the CI sub-project lands.

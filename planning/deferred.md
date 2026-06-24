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
- **Integration tests don't run in CI** — `just test` is `flutter test` (unit/
  widget only); `integration_test/` needs a booted emulator/simulator and runs
  only locally. This let `critical_flow_test.dart` rot red for ~10 days
  (missing l10n delegates after i18n localized the home screen) with nothing to
  catch it. *Revisit when* CI gains a device runner (e.g. a macOS job with an
  Android AVD or the `reactivecircus/android-emulator-runner` action), or when an
  integration test next rots unnoticed.
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

- **Timezone change while foregrounded** (audit, disputed remainder) — `tz.local`
  is now refreshed at init and on app resume, so travel-then-open is covered; an
  app kept in the foreground across a zone change still won't resync until the
  next resume. *Revisit when* reported. Fix: a platform timezone-change broadcast
  listener + `tz.setLocalLocation` + resync.
- **Open-system-settings from the notifications-off warning** — the Settings
  warning is a hint only; a tappable "open settings" deep-link needs a new dep
  (`app_settings`/`permission_handler`). *Revisit when* that dep is justified.
- **`NotificationService.syncSchedule` plugin calls untested** — the real
  cancel-all-then-`zonedSchedule` sequence is only covered at the coordinator
  layer (via a fake); the literal plugin calls would need a mock-method-channel
  test. *Revisit if* the scheduling glue changes.

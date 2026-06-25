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

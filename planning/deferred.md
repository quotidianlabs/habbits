# Deferred

Real-but-unscheduled items. Each has a revisit trigger. Promote one into a
change file when its trigger fires.

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

## Runtime schema self-check (`validateDatabaseSchema` in `beforeOpen`)

Drift can validate the live database against its declared schema at startup via
`validateDatabaseSchema()`. We deliberately did not adopt it with the
schema-verifier harness (see
[`changes/2026-07-05.01-schema-verifier-harness.md`](changes/2026-07-05.01-schema-verifier-harness.md)):
it is imported from `drift_dev`, so calling it from `lib/` pulls the analyzer /
build stack into the app's *runtime* dependency graph. The CI `schema-check`
gate already covers schema-drift.

**Revisit trigger:** we want a debug-build, app-startup schema self-check
(e.g. after a migration bug slips past CI) and have confirmed a way to invoke
`validateDatabaseSchema` without adding `drift_dev` to runtime deps.

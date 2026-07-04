# nooka vs habbits: cross-app audit

Date: 2026-07-04

Both apps share a lineage and are kept in sync on tooling. This audit compares
`habbits` against its sibling `nooka` (`../tasks`, package
`io.github.quotidianlabs.nooka`) and flags what else could be ported. Rows
closed by the RuStore/release-notes work (see
`docs/superpowers/plans/2026-07-04-rustore-publishing-and-release-notes.md`) are
marked **Done here**.

## CI/CD

| Item | nooka | habbits | Call | Recommendation |
|------|-------|---------|------|----------------|
| Curated stable-tag notes verbatim | yes | **Done here** | Portable | Shipped in this branch |
| Guarded RuStore upload | yes (#41) | **Done here** | Portable | Shipped in this branch |
| GitHub Pages privacy site (`pages.yml` + `site/`) | yes | **Done here** | Portable | Shipped in this branch |
| Docs/planning-only CI skip (`paths-ignore` `**/*.md`, `planning/**`, `architecture/**`, `docs/**`) | yes (#37) | no | Portable | Small, high-value; add `paths-ignore` to `ci.yml`. Note the caveat nooka documents: safe only while `main` has no required checks — else add an always-running gate job. |

## Features

| Item | nooka | habbits | Call | Recommendation |
|------|-------|---------|------|----------------|
| Google Drive cloud backup | yes (#32, #33) | no (local JSON only) | Portable | Largest gap. Needs its own spec: Google OAuth web client ID, `drive.appdata` scope, `--dart-define=GOOGLE_SERVER_CLIENT_ID` in release build, privacy-policy update to re-add the Drive section. |
| Delete an active item + undo toast | yes (#34) | habbits deletes habits (core UX) | Divergent-by-design | Different domain; no action. |

## Architecture / docs

| Item | nooka | habbits | Call | Recommendation |
|------|-------|---------|------|----------------|
| Architecture doc layout | grouped (`home-coordination.md`, `error-handling.md`, `archive.md`, single `i18n-theming.md`) | per-capability split (`habit-tracking.md`, `streaks-and-stats.md`, `reminders.md`, `i18n.md`, `theming.md`) | Divergent-by-design | Each reflects its app's capabilities; no action. |

## Build / deps

| Item | nooka | habbits | Call | Recommendation |
|------|-------|---------|------|----------------|
| AGP / Kotlin versions | 9.0.1 / 2.3.20 | 9.0.1 / 2.3.20 | Aligned | No action — already in sync. |
| App version | 1.2.2+6 | 1.0.0+1 | Expected skew | Independent release cadence; no action. |
| `pubspec.yaml` dependency set | includes Google Drive / OAuth deps | no Drive deps | Follows the Drive-backup decision | Revisit if Drive backup is ported. |

## Suggested next specs (in priority order)
1. Docs-only CI skip (tiny, mirrors nooka #37).
2. Google Drive cloud backup (large; own brainstorming cycle).

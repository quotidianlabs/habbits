---
status: draft
date: 2026-06-15
slug: readme-and-license
supersedes: null
superseded_by: null
pr: null
outcome: null
---

# Design: README + MIT LICENSE (with en/ru screenshots)

## Summary

Add a root `README.md` (pitch, screenshots, features, architecture, getting
started, testing, license) and an `LICENSE` file (MIT, © 2026 quotidianlabs).
Generate a compact set of fresh screenshots from the iOS simulator into
`assets/screenshots/` and embed them. This is what a visitor to the public repo
sees first; right now there is nothing.

## Motivation

The public repo has **no README and no LICENSE**. Without a README the project
undersells everything built (cross-platform, local-first, bilingual, layered
architecture); without a license it is legally "all rights reserved", which
contradicts the open-source intent. Screenshots — especially the en/ru pair —
communicate the app faster than prose.

## Non-goals

- **Full screenshot gallery / every screen** — a compact set only (see Design).
- **`architecture/` truth-home docs** — deferred (tracked in `deferred.md`); the
  README's architecture section links the shipped change bundles in `planning/`
  instead.
- **Badges beyond CI + license** — keep it lean.

## Design

### 1. `LICENSE` (repo root)

Standard MIT license text, `Copyright (c) 2026 quotidianlabs`.

### 2. Screenshots (`assets/screenshots/`)

Captured from the booted iOS simulator (`habbits_ios`). Sample habits are seeded
first (so screens aren't empty) by importing a small backup JSON via the app's
own import flow, or a one-off debug seed — exact mechanism nailed in the plan.
Capture four PNGs:

- `home-en.png` — home list with a few habits (streaks + day-strip), English.
- `home-ru.png` — the same, Russian (highlights the i18n).
- `detail-en.png` — habit detail (6-week heatmap + reminder), English.
- `settings-en.png` — settings with the language picker open, English.

Committed under `assets/screenshots/`, **not** added to `flutter: assets:` (they
are README images, not bundled runtime assets — same treatment as the icon
source).

### 3. `README.md` (repo root)

Top to bottom:

- **Title + tagline** — "Habbits — a local-first, cross-platform habit tracker.
  Your data, on your device." + a row of badges: **CI status**
  (`github/actions/workflows/ci.yml`), **License** (MIT), **Flutter**.
- **Screenshots** — the four images in a small markdown table so they sit in a
  row.
- **Features** — checklist: daily check-off + streaks; 6-week heatmap +
  recent-days editing; per-habit local-notification reminders; drag-to-reorder;
  JSON export/import (data ownership); **English + Russian** with auto/locale
  override; Material 3 UI; iOS + Android.
- **Architecture** — a short paragraph: layered MVVM with Riverpod (UI views +
  view models → domain → data repositories over Drift), linking the design
  bundles in `planning/changes/archive/` (notably `architecture-refactor`).
- **Getting started** — prerequisites (Flutter 3.44.2), `flutter pub get`,
  `flutter run`; note generated code is committed (no `build_runner` needed for a
  normal run); mention `just lint` / `just test` (from the CI change).
- **Testing** — `flutter analyze`, `flutter test` (115), the integration test
  command.
- **License** — MIT, linking `LICENSE`.

## Operations

None. The CI badge URL assumes the `ci.yml` workflow exists — this change is
sequenced **after** the `ci-and-justfile` change, so the badge resolves.

## Testing

- All README image paths and the `LICENSE` link resolve (relative paths).
- The four screenshots exist under `assets/screenshots/` at sensible dimensions.
- `flutter analyze` clean and `flutter test` = 115 (no code change; screenshots
  aren't bundled).

## Risk

- **Screenshot seeding is fiddly** (medium likelihood, low impact): the import
  flow on the simulator can be awkward; mitigated by allowing a one-off debug
  seed and by re-shooting if a screen looks wrong.
- **Stale screenshots** as the UI evolves (low): acceptable for a portfolio
  README; re-shoot on major UI changes.

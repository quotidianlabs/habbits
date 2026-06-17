# Planning

Specs, plans, and change history for Habbits. This directory records *how the
system got to where it is*. The living truth about *what it does now* lives in
[`architecture/`](../architecture/README.md) at the repo root.

## Conventions

> This section is the portable convention — identical across the sibling repos.
> The Index below is repo-specific. To adopt elsewhere, copy this section plus
> [`_templates/`](_templates/) and point that repo's `CLAUDE.md` workflow at it.

### Two axes, never mixed

- **`architecture/` (repo root) — the present.** One file per capability,
  living prose, updated whenever a change ships. The truth home.
- **`planning/changes/` — the past-and-pending.** One folder per change, frozen
  once shipped.

Shipping a change **promotes** its conclusions into the affected
`architecture/<capability>.md` by hand, then archives the bundle.

### Change bundles

A change is a folder `changes/active/YYYY-MM-DD.NN-<slug>/`:

- `YYYY-MM-DD` — proposal date; `.NN` — zero-padded intra-day counter that
  breaks same-date ties so the timeline sorts stably.
- `<slug>` — kebab-case description, not a story ID.

On merge the folder moves to `changes/archive/` with `status: shipped`, `pr:`,
and `outcome:` filled, and its line moves from **Active** to **Archived** below.

### Three lanes

| Lane | Artifacts | Use when |
|------|-----------|----------|
| **Full** | `design.md` + `plan.md` | design judgment; new file/module; public-API change; cross-cutting/multi-file; non-trivial test design |
| **Lightweight** | `change.md` | small-but-real: ≲30 LOC net, ≤2 files, no new file, no public-API change, single straightforward test |
| **Tiny** | none — conventional commit | typo, dep bump, linter/formatter/CI tweak, mechanical rename, single-line config |

Heavier lane wins on ambiguity. A `change.md` that outgrows its lane splits into
`design.md` + `plan.md`.

### Artifacts at a glance

- **`design.md`** — the spec: the *thinking* (why, design, trade-offs, scope).
- **`plan.md`** — the plan: the *sequencing* (the executor's task checklist).
- **`change.md`** — both, condensed, for the lightweight lane.
- **`deferred.md`** — real-but-unscheduled items, each with a revisit trigger.

Templates live in [`_templates/`](_templates/).

### Frontmatter

`design.md` / `change.md`: `status` (draft|approved|shipped|superseded), `date`,
`slug`, `supersedes`, `superseded_by`, `pr`, `outcome`. `plan.md`: `status`,
`date`, `slug`, `spec`, `pr`. Files in `architecture/` carry **no** frontmatter.

## Index

### Active

_None._

### Archived (shipped)

- **[completion-pct-first-check](changes/archive/2026-06-17.01-completion-pct-first-check/change.md)**
  (#11, 2026-06-17) — Anchor the 30-day completion % at the first checked day
  instead of `createdAt`, so pre-creation backfilled checks count and the
  denominator follows activity span, not creation span; unstarted habits render
  "—".

- **[release-signing](changes/archive/2026-06-16.01-release-signing/change.md)**
  (#9, 2026-06-16) — Android upload-key signing (gitignored keystore +
  `key.properties`), `compileSdk`/`targetSdk` pinned to 36, and a
  `docs/release.md` runbook — `flutter build appbundle --release` is now
  Play-uploadable.

- **[dark-theme-and-color-picker](changes/archive/2026-06-15.07-dark-theme-and-color-picker/design.md)**
  (#6, 2026-06-15) — App-wide dark theme with a System/Light/Dark selector +
  dark-adaptive activity grids, and a curated per-habit color picker on
  create/edit.
- **[architecture-capability-docs](changes/archive/2026-06-15.06-architecture-capability-docs/design.md)**
  (#5, 2026-06-15) — Bootstrap the `architecture/` truth-home: six capability
  docs + an index, written from live code and archived bundles.
- **[readme-and-license](changes/archive/2026-06-15.05-readme-and-license/design.md)**
  (#4, 2026-06-15) — Project README (badges, en/ru screenshots, features,
  architecture) + MIT LICENSE.
- **[ci-and-justfile](changes/archive/2026-06-15.04-ci-and-justfile/design.md)**
  (#3, 2026-06-15) — GitHub Actions CI + Justfile (lint/test) with a repo-wide
  dart-format pass.
- **[adopt-planning-convention](changes/archive/2026-06-15.03-adopt-planning-convention/design.md)**
  (#2, 2026-06-15) — Adopt the portable planning convention; migrate 9 shipped
  specs/plans into archive bundles.
- **[app-icon-branding](changes/archive/2026-06-15.02-app-icon-branding/design.md)**
  (#1, 2026-06-15) — Activity-grid app icon + bundle id
  `io.github.quotidianlabs.habbits`.
- **[architecture-refactor](changes/archive/2026-06-15.01-architecture-refactor/design.md)**
  (86f0a38, 2026-06-15) — Layered MVVM with Riverpod: repositories, per-feature
  view models, feature-first tree.
- **[russian-language](changes/archive/2026-06-14.04-russian-language/design.md)**
  (aff47ab, 2026-06-14) — Full en/ru i18n: gen-l10n, locale controller,
  locale-aware dates, Russian plurals.
- **[reorder-habits](changes/archive/2026-06-14.03-reorder-habits/design.md)**
  (2c197d1, 2026-06-14) — Drag-to-reorder the home list via a per-card handle.
- **[reminders](changes/archive/2026-06-14.02-reminders/design.md)**
  (local, 2026-06-14) — Per-habit local-notification reminders.
- **[export-import](changes/archive/2026-06-14.01-export-import/design.md)**
  (local, 2026-06-14) — JSON export/import with strict backup validation.
- **[usability-v2](changes/archive/2026-06-13.03-usability-v2/design.md)**
  (local, 2026-06-13) — Usability pass across home, detail, and dialogs.
- **[heatmap-retroactive-editing](changes/archive/2026-06-13.02-heatmap-retroactive-editing/design.md)**
  (local, 2026-06-13) — Detail-screen heatmap + retroactive check-off.
- **[foundation](changes/archive/2026-06-13.01-foundation/design.md)**
  (local, 2026-06-13) — Initial local-first core loop.

---
status: shipped
date: 2026-06-15
slug: architecture-capability-docs
summary: Bootstrap the `architecture/` truth-home: six capability docs + an index, written from live code and archived bundles.
supersedes: null
superseded_by: null
pr: 5
outcome: >
  Shipped the architecture/ truth-home: an index plus six capability docs
  written from live code. Also processed planning/legacy/ (removed the BMAD
  briefs, distilled best-streak + non-daily cadence to deferred.md) and added
  the color-picker and dark-theme deferred items. Docs-only; no code touched;
  115 tests still pass.
---

# Design: Bootstrap the `architecture/` truth-home capability docs

## Summary

Create the `architecture/` directory the planning convention has promised since
its adoption: living, frontmatter-free capability docs at the repo root that
describe *what the system does now*. Bootstrap six capability docs
(habit-tracking, streaks-and-stats, reminders, backup-io, i18n, theming) plus a
one-screen `architecture/README.md` index, each written from the live code and
the relevant archived change bundles. Then drop the now-obsolete "forthcoming"
hedges in `planning/README.md` and `CLAUDE.md`, and remove the completed item
from `planning/deferred.md`.

## Motivation

The planning convention is built on **two axes**: `planning/changes/` records
*how the system got here* (the past-and-pending), and `architecture/` records
*what it does now* (the present, the "truth home"). Only the first axis exists.
`architecture/` has been "forthcoming" through every change since the convention
was adopted (#2), and `planning/README.md` describes a "promote conclusions into
`architecture/<capability>.md` on ship" step that points at files that do not
exist.

The product core is complete and stable (foundation, heatmap, export/import,
reminders, reorder, i18n, layered-MVVM refactor all shipped), so the capability
seams are now settled enough to document without churn. This is the "next docs
pass" the deferred item names as its revisit trigger.

## Non-goals

- No code changes. This is documentation only; not a single `lib/` or `test/`
  file is touched.
- Not the other deferred items. The trigger-gated cleanups (iPad popover,
  notification channel name, `TextEditingController` disposal, backup test
  naming), test-folder mirroring, and Codecov upload stay deferred.
- Not a tutorial or contributor onboarding guide. These docs state the present
  contract; rationale and history live in the change bundles they link to.
- No frontmatter on `architecture/` files — the convention is explicit that the
  truth-home carries none.

## Design

### 1. The capability set

Six docs, one per capability, matching the `deferred.md` list and the code
seams exactly:

| Doc | Primary code |
|-----|--------------|
| `habit-tracking.md` | `data/repositories/habit_repository.dart`, `data/services/database/habit_dao.dart`, `data/services/database/database.dart`, `domain/reorder.dart`, `domain/models/habit_*.dart`, `ui/habit_list/`, `ui/habit_detail/`, `ui/widgets/habit_dialogs.dart` |
| `streaks-and-stats.md` | `domain/streak.dart`, `domain/completion_stats.dart`, `domain/heatmap.dart`, `domain/recent_days.dart`, `domain/dates.dart`, `ui/widgets/heatmap_grid.dart`, `ui/widgets/day_strip.dart`, `ui/widgets/recent_days_list.dart` |
| `reminders.md` | `data/services/notification_service.dart`, `domain/reminder_schedule.dart`, `ui/core/reminder_coordinator.dart` |
| `backup-io.md` | `data/repositories/backup_repository.dart`, `domain/backup_codec.dart`, `domain/models/backup_data.dart` |
| `i18n.md` | `l10n/`, `ui/core/locale_controller.dart`, language switch in `ui/settings/` |
| `theming.md` | `ui/core/theme.dart`, theme-mode persistence in `data/repositories/settings_repository.dart` |

`settings_repository.dart` persists both locale and theme mode; it is described
from both the i18n and theming docs rather than getting its own file.

### 2. Per-doc shape

Each capability doc is present-tense prose, no frontmatter, with these sections:

- **Purpose** — one line: what this capability is.
- **Behavior** — what it does today from the user's view.
- **Code map** — the implementing files/types as clickable `path:line` refs.
- **Invariants** — the contracts that must hold. Concrete, e.g. for streaks:
  *a streak counts consecutive completed days up to and including today; a
  single missed day breaks it.*
- **Known edges** — current limitations and the `deferred.md` items that touch
  this capability (see §4 for the duplication call).
- **History** — a trailing link line to the archived change bundle(s) that
  produced this capability. This is the concrete target of the convention's
  "promote on ship" step.

### 3. `architecture/README.md`

A one-screen overview: the app in three to four sentences, the layered-MVVM map
(`ui → domain → data`, Riverpod wiring, Drift database), and a table linking the
six capability docs with a one-line gloss each. This is the entry point a reader
hits first; it is not itself a capability doc.

### 4. Known-edges ↔ deferred.md

Each doc's **Known edges** section actively names the `deferred.md` items that
touch its capability (e.g. theming notes the un-localized Android channel name;
backup-io notes the iPad popover-anchor crash). This duplicates the backlog
across two homes, accepted deliberately: a capability doc that hides its own
gaps is not an honest truth-home. `deferred.md` remains the scheduling home (it
carries the revisit triggers); the docs only mirror the *fact* of the gap.

### 5. Sourcing

Every doc is written from two grounds, read fresh per capability:

1. The capability's archived `design.md`(s) under
   `planning/changes/`, for intent and vocabulary.
2. The live code, for what is actually true now.

On any conflict, **code wins** — these docs describe the present, and specs can
drift from what shipped.

### 6. Housekeeping edits

- `planning/README.md` — remove the three "(Forthcoming for this repo.)" /
  "(forthcoming — see deferred.md)" hedges; rewrite the "promote into
  `architecture/<capability>.md`" sentence to reference the now-real files.
- `CLAUDE.md` — drop "(forthcoming)" from the `architecture/` mention in the
  project guide.
- `planning/deferred.md` — remove the completed `architecture/` truth-home line.

## Out of scope

- Wiring a CI check that fails when a shipped change does not touch an
  `architecture/` doc. Worth considering later; not part of this bootstrap.
- Backfilling per-doc "History" links retroactively for every micro-change —
  the History line lists the defining bundle(s), not an exhaustive changelog.

## Testing

Docs-only, so verification is by inspection, not a test run:

- `flutter analyze` and `flutter test` still pass unchanged (no code touched) —
  a sanity check, not the point.
- Every `path:line` reference in every Code map resolves to a real symbol in the
  current tree.
- Every internal link (README → capability docs, docs → archived bundles)
  resolves.
- No `architecture/` file carries frontmatter.
- `planning/README.md`, `CLAUDE.md`, and `deferred.md` no longer describe
  `architecture/` as forthcoming or list it as a pending item.

## Risk

- **Docs drift from code over time** (likely × moderate). The whole convention's
  bet. Mitigated structurally by the "promote on ship" step now having a real
  target, and by keeping each doc small enough that updating it on a relevant
  change is cheap. Out of scope to enforce mechanically here (see Out of scope).
- **Backlog duplication goes stale** (moderate × low). A `deferred.md` item is
  resolved but its mirror in a doc's Known edges lingers. Mitigated by keeping
  the mirror to a one-line *fact* with no trigger detail, so the doc reads as a
  pointer, not a second source of truth.
- **Over-documentation** (low × low). Risk of writing aspirational or tutorial
  prose. Mitigated by the fixed per-doc shape and the present-tense,
  code-wins-on-conflict rule.

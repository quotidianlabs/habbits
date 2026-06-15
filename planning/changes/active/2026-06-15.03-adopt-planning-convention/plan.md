---
status: draft
date: 2026-06-15
slug: adopt-planning-convention
spec: adopt-planning-convention
pr: null
---

# adopt-planning-convention — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the `planning/` convention, migrate the 9 shipped spec/plan pairs into archived change bundles, seed `deferred.md`, add a project `CLAUDE.md`, relocate the legacy briefs, and delete `docs/superpowers/` — with no application-code change.

**Architecture:** Pure documentation reorganization — create scaffolding files, `git mv` existing specs/plans into `planning/changes/archive/<bundle>/{design,plan}.md`, prepend frontmatter, build a README Index. The 115-test suite must stay green throughout (proof that no code moved).

**Tech Stack:** Markdown, git. No Dart/build changes.

**Spec:** [`design.md`](./design.md)

**Branch:** `chore/planning-convention`

**Conventions:**
- `export PATH="/opt/homebrew/bin:$PATH"` before flutter commands.
- `.claude/` is gitignored — safe; still, **never use `git add -A`/`git add .`** in this plan. Stage explicit paths only.
- Gate every task on: `flutter analyze` clean + `flutter test` = 115 passing (unchanged — this work touches no `lib/`/`test/`), plus the structural checks in each task.

**Pre-flight:**
```bash
export PATH="/opt/homebrew/bin:$PATH"
flutter analyze && flutter test   # baseline: clean + 115
git switch -c chore/planning-convention
```

---

## Task 1: Scaffold `planning/` (templates, dirs, deferred, CLAUDE.md)

**Files:**
- Create: `planning/_templates/design.md`, `planning/_templates/plan.md`, `planning/_templates/change.md`
- Create: `planning/changes/active/.gitkeep`, `planning/changes/archive/.gitkeep`
- Create: `planning/deferred.md`
- Create: `CLAUDE.md` (repo root)

- [ ] **Step 1: Create `planning/_templates/design.md`** (verbatim convention template):
```markdown
---
status: draft
date: YYYY-MM-DD
slug: my-change
supersedes: null
superseded_by: null
pr: null
outcome: null
---

# Design: One-line capitalized title

## Summary

One paragraph. What changes, at the level a reader needs to decide if this
spec is worth reading in full.

## Motivation

Why now. What is broken or missing. Concrete observations / numbers, not
abstract complaints. Link to memory entries or earlier specs when relevant.

## Non-goals

What is deliberately out of scope and (when nontrivial) why. Each item is
a sentence; one line each.

## Design

### 1. <First piece>

What changes, in enough detail that a reader who has not seen the codebase
can follow. Code samples / diagrams welcome.

### 2. <Second piece>

...

## Operations

Out-of-repo steps (DNS, infra, external account changes). Omit if none.

## Out of scope

Already covered above under Non-goals if appropriate. Repeat-list of
explicitly-excluded follow-ups belongs here when the list is long.

## Testing

How we know it landed correctly. New test? Smoke check? Lint pass? Be specific.

## Risk

What could go wrong, ranked by likelihood × impact. Mitigations.
```

- [ ] **Step 2: Create `planning/_templates/plan.md`** (convention template; note the `Co-Authored-By` trailer uses Opus 4.8 to match this repo):
```markdown
---
status: draft
date: YYYY-MM-DD
slug: my-change
spec: my-change
pr: null
---

# <slug> — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps
> use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One sentence — what shipping this plan achieves. No design
rationale; link to the spec for that.

**Spec:** [`design.md`](./design.md)

**Branch:** `feat/my-change` (or `fix/`, `chore/`, etc.)

**Commit strategy:** Per-task commits / single commit / squash on merge.
Whichever fits.

---

### Task 1: <imperative description>

**Files:**
- Modify: `path/to/file.dart`
- Create: `path/to/new.dart`

One sentence on what this task accomplishes. No deeper reasoning — that's
in the spec.

- [ ] **Step 1: <action>**

  Run / edit / verify command. Expected output.

- [ ] **Step 2: <action>**

  ...

- [ ] **Step 3: Commit**

  ```bash
  git add path/to/file.dart
  git commit -m "<type>: <subject>

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 2: ...
```

- [ ] **Step 3: Create `planning/_templates/change.md`** (verbatim convention template; adapt the example commands to this repo's `just`/`flutter`):
```markdown
---
status: draft
date: YYYY-MM-DD
slug: my-change
supersedes: null
superseded_by: null
pr: null
outcome: null
---

# Change: One-line capitalized title

**Lane:** lightweight — ≲30 LOC net, ≤2 files, no new file, no public-API
change, a single straightforward test. If it outgrows this, split into
`design.md` + `plan.md`.

## Goal

One or two sentences: what changes and why.

## Approach

The shape of the change in brief — enough that a reviewer sees the design
without a full spec. Link the truth home (`architecture/<capability>.md`) if a
capability contract moves.

## Files

- `path/to/file.dart` — what changes
- `test/path/x_test.dart` — test added / updated

## Verification

- [ ] Failing test first — command + expected error.
- [ ] Apply the change.
- [ ] Test passes — command.
- [ ] `flutter test` — full suite green (115).
- [ ] `flutter analyze` — clean.
```

- [ ] **Step 4: Create the change dirs**
```bash
cd /Users/kevinsmith/src/habbits
mkdir -p planning/changes/active planning/changes/archive
touch planning/changes/active/.gitkeep planning/changes/archive/.gitkeep
```

- [ ] **Step 5: Create `planning/deferred.md`**
```markdown
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
- **Backup test-file naming inversion** — `test/domain/backup_test.dart` covers
  the pure codec while `backup_codec_test.dart` covers DB-backed `buildBackup`;
  the names are swapped. *Revisit when* either file is next edited.
- **`test/ui/` screen/widget tests not mirrored** into feature subfolders
  (e.g. `habit_list_screen_test.dart` sits flat, not under `test/ui/habit_list/`).
  *Revisit on* the next test-organization pass.
- **Codecov coverage upload** — `flutter test --coverage` + `codecov-action`,
  matching the sibling repos. *Revisit when* the CI sub-project lands.
```

- [ ] **Step 6: Create the project `CLAUDE.md`** (repo root):
```markdown
# Habbits — project guide

Local-first habit tracker (Flutter, iOS + Android, English + Russian).
Architecture: layered MVVM with Riverpod — see the shipped change bundles in
`planning/`.

## Workflow

Design + plan for every non-trivial change live in `planning/`. Read
`planning/README.md` for the full convention. In short:

- A change is a bundle `planning/changes/active/YYYY-MM-DD.NN-<slug>/` with
  `design.md` + `plan.md` (Full lane) or `change.md` (Lightweight); on merge it
  moves to `planning/changes/archive/`.
- Real-but-unscheduled items live in `planning/deferred.md`.
- The `architecture/` truth-home capability docs are forthcoming (tracked in
  `planning/deferred.md`).

## Commands

`flutter analyze` and `flutter test` (115 tests) — a `Justfile` (`just lint` /
`just test`) is forthcoming. Generated `*.g.dart` is committed; run
`dart run build_runner build --delete-conflicting-outputs` after touching
`@riverpod`/Drift code.
```

- [ ] **Step 7: Verify + commit**
```bash
export PATH="/opt/homebrew/bin:$PATH"
flutter analyze   # unchanged, clean
ls planning/_templates planning/changes/active planning/changes/archive
git add planning/_templates planning/changes CLAUDE.md
git commit -m "chore(planning): scaffold convention (templates, dirs, deferred, CLAUDE.md)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Migrate the 9 shipped changes into archive bundles

**Files:**
- Move: each `docs/superpowers/specs/<spec>.md` → `planning/changes/archive/<bundle>/design.md`
- Move: each `docs/superpowers/plans/<plan>.md` → `planning/changes/archive/<bundle>/plan.md`
- Prepend frontmatter to each moved file.

**Bundle / source / frontmatter values** (`pr` and `outcome` are exact; bodies move unchanged):

| bundle | spec source | plan source | date | slug | pr | outcome |
|---|---|---|---|---|---|---|
| `2026-06-13.01-foundation` | `habbits-mobile-local-first-design.md` | `foundation-core-loop.md` | 2026-06-13 | `foundation` | merged to main locally | Initial local-first core loop: Drift schema, daily check-off, streaks, home list. |
| `2026-06-13.02-heatmap-retroactive-editing` | `heatmap-retroactive-editing-design.md` | `heatmap-retroactive-editing.md` | 2026-06-13 | `heatmap-retroactive-editing` | merged to main locally | Detail-screen heatmap + retroactive check-off via the recent-days list. |
| `2026-06-13.03-usability-v2` | `usability-v2-design.md` | `usability-v2.md` | 2026-06-13 | `usability-v2` | merged to main locally | Usability pass across home, detail, and dialogs. |
| `2026-06-14.01-export-import` | `export-import-design.md` | `export-import.md` | 2026-06-14 | `export-import` | merged to main locally | JSON export/import (share + file picker) with strict backup validation. |
| `2026-06-14.02-reminders` | `reminders-design.md` | `reminders.md` | 2026-06-14 | `reminders` | merged to main locally | Per-habit local-notification reminders (flutter_local_notifications + timezone). |
| `2026-06-14.03-reorder-habits` | `reorder-habits-design.md` | `reorder-habits.md` | 2026-06-14 | `reorder-habits` | 2c197d1 | Drag-to-reorder the home list via a per-card handle with persisted sortOrder. |
| `2026-06-14.04-russian-language` | `russian-language-design.md` | `russian-language.md` | 2026-06-14 | `russian-language` | aff47ab | Full en/ru i18n: gen-l10n, locale controller, locale-aware dates, Russian plurals. |
| `2026-06-15.01-architecture-refactor` | `architecture-refactor-design.md` | `architecture-refactor.md` | 2026-06-15 | `architecture-refactor` | 86f0a38 | Layered MVVM with Riverpod: repositories, per-feature view models, feature-first tree. |
| `2026-06-15.02-app-icon-branding` | `app-icon-branding-design.md` | `app-icon-branding.md` | 2026-06-15 | `app-icon-branding` | #1 (bbb0a93) | Activity-grid app icon + bundle id `io.github.quotidianlabs.habbits`. |

> If a body's opening already differs from the table's one-liner, keep the table's `outcome` (it is the canonical index summary); do not rewrite the body.

- [ ] **Step 1: Move all 18 files into bundle dirs** (spec→`design.md`, plan→`plan.md`):
```bash
cd /Users/kevinsmith/src/habbits
S=docs/superpowers/specs; P=docs/superpowers/plans; A=planning/changes/archive
declare -a rows=(
  "2026-06-13.01-foundation|$S/2026-06-13-habbits-mobile-local-first-design.md|$P/2026-06-13-foundation-core-loop.md"
  "2026-06-13.02-heatmap-retroactive-editing|$S/2026-06-13-heatmap-retroactive-editing-design.md|$P/2026-06-13-heatmap-retroactive-editing.md"
  "2026-06-13.03-usability-v2|$S/2026-06-13-usability-v2-design.md|$P/2026-06-13-usability-v2.md"
  "2026-06-14.01-export-import|$S/2026-06-14-export-import-design.md|$P/2026-06-14-export-import.md"
  "2026-06-14.02-reminders|$S/2026-06-14-reminders-design.md|$P/2026-06-14-reminders.md"
  "2026-06-14.03-reorder-habits|$S/2026-06-14-reorder-habits-design.md|$P/2026-06-14-reorder-habits.md"
  "2026-06-14.04-russian-language|$S/2026-06-14-russian-language-design.md|$P/2026-06-14-russian-language.md"
  "2026-06-15.01-architecture-refactor|$S/2026-06-15-architecture-refactor-design.md|$P/2026-06-15-architecture-refactor.md"
  "2026-06-15.02-app-icon-branding|$S/2026-06-15-app-icon-branding-design.md|$P/2026-06-15-app-icon-branding.md"
)
for r in "${rows[@]}"; do IFS='|' read -r b spec plan <<<"$r"; mkdir -p "$A/$b"; git mv "$spec" "$A/$b/design.md"; git mv "$plan" "$A/$b/plan.md"; done
ls planning/changes/archive
```
Expected: 9 bundle dirs, each containing `design.md` + `plan.md`.

- [ ] **Step 2: Prepend frontmatter to each `design.md` and `plan.md`.**
For each bundle, prepend (at the very top of the file, before its `#` heading) the blocks below, substituting the row's `date`, `slug`, `pr`, `outcome`. Use the `Edit` tool to insert at the file head (do not alter the existing body).

`design.md` frontmatter:
```yaml
---
status: shipped
date: <date>
slug: <slug>
supersedes: null
superseded_by: null
pr: <pr>
outcome: <outcome>
---

```
`plan.md` frontmatter:
```yaml
---
status: shipped
date: <date>
slug: <slug>
spec: <slug>
pr: <pr>
---

```
Do this for all 9 bundles (18 files) using the table values.

- [ ] **Step 3: Verify every old file moved + frontmatter present**
```bash
cd /Users/kevinsmith/src/habbits
echo "old dirs should be empty:"; ls docs/superpowers/specs docs/superpowers/plans 2>/dev/null
echo "each bundle has 2 files with frontmatter:"
for d in planning/changes/archive/*/; do echo "$d -> $(ls "$d" | tr '\n' ' ')"; head -1 "$d/design.md"; head -1 "$d/plan.md"; done
```
Expected: the two old dirs are empty; every `design.md`/`plan.md` starts with `---`.

- [ ] **Step 4: Commit**
```bash
git add planning/changes/archive docs/superpowers
git commit -m "docs(planning): migrate 9 shipped specs/plans into archive bundles

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: README (Conventions + Index), relocate legacy, delete old docs

**Files:**
- Create: `planning/README.md`
- Move: `docs/bmad-legacy/` → `planning/legacy/`
- Delete: `docs/superpowers/` (now-empty), and `docs/` if empty.

- [ ] **Step 1: Relocate the legacy briefs + remove the empty old tree**
```bash
cd /Users/kevinsmith/src/habbits
mkdir -p planning/legacy
git mv docs/bmad-legacy/README.md planning/legacy/README.md
git mv docs/bmad-legacy/prd.md planning/legacy/prd.md
git mv docs/bmad-legacy/product-brief-habbits.md planning/legacy/product-brief-habbits.md
git mv docs/bmad-legacy/product-brief-habbits-distillate.md planning/legacy/product-brief-habbits-distillate.md
rmdir docs/bmad-legacy docs/superpowers/specs docs/superpowers/plans docs/superpowers docs 2>/dev/null; true
git status --short | grep -E 'docs/' || echo "docs/ fully removed"
```

- [ ] **Step 2: Create `planning/README.md`** — the portable Conventions section + the repo Index:
````markdown
# Planning

Specs, plans, and change history for Habbits. This directory records *how the
system got to where it is*. The living truth about *what it does now* will live
in `architecture/` at the repo root (forthcoming — see
[`deferred.md`](deferred.md)).

## Conventions

> This section is the portable convention — identical across the sibling repos.
> The Index below is repo-specific. To adopt elsewhere, copy this section plus
> [`_templates/`](_templates/) and point that repo's `CLAUDE.md` workflow at it.

### Two axes, never mixed

- **`architecture/` (repo root) — the present.** One file per capability,
  living prose, updated whenever a change ships. The truth home. *(Forthcoming
  for this repo.)*
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
- **`legacy/`** — pre-history product briefs (BMAD), kept for provenance.

Templates live in [`_templates/`](_templates/).

### Frontmatter

`design.md` / `change.md`: `status` (draft|approved|shipped|superseded), `date`,
`slug`, `supersedes`, `superseded_by`, `pr`, `outcome`. `plan.md`: `status`,
`date`, `slug`, `spec`, `pr`. Files in `architecture/` carry **no** frontmatter.

## Index

### Active

_None._

### Archived (shipped)

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

> `adopt-planning-convention` (this change) is in **Active** until it ships, then
> moves here.
````

- [ ] **Step 3: Verify Index links resolve**
```bash
cd /Users/kevinsmith/src/habbits
grep -oE 'changes/archive/[^)]+design\.md' planning/README.md | while read -r p; do test -f "planning/$p" && echo "ok $p" || echo "BROKEN $p"; done
```
Expected: every line `ok …`; no `BROKEN`.

- [ ] **Step 4: Commit**
```bash
git add planning/README.md planning/legacy
git commit -m "docs(planning): README (conventions + index); relocate legacy briefs

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Final verification

**Files:** none (verification only)

- [ ] **Step 1: No orphans, no stray `docs/`, code untouched**
```bash
cd /Users/kevinsmith/src/habbits
export PATH="/opt/homebrew/bin:$PATH"
test -d docs && echo "docs/ STILL EXISTS" || echo "docs/ gone ✓"
find planning -name '*.md' | wc -l    # expect 3 templates + 9*2 + README + deferred + this change's 2 = 25
echo "every archived bundle frontmatter:"; grep -L '^---' planning/changes/archive/*/*.md || echo "all have frontmatter ✓"
flutter analyze
flutter test
```
Expected: `docs/` gone; no files missing frontmatter; analyze clean; 115 tests pass (confirming zero code change).

- [ ] **Step 2: Confirm git history records the moves as renames** (so the prose is preserved, not re-added)
```bash
git log --oneline -4
git show --stat HEAD~1 | grep -E "rename|=>" | head
```
Expected: the migration commit shows `rename` entries for the moved specs/plans.

- [ ] **Step 3: Done** — no commit. Hand back for branch finish.

---

## Promotion at merge (closing note, not a task)

This change's own bundle stays in `planning/changes/active/2026-06-15.03-adopt-planning-convention/` through implementation. When this branch merges, promote it:
- `git mv planning/changes/active/2026-06-15.03-adopt-planning-convention planning/changes/archive/`
- set `status: shipped`, `pr: <merge ref>`, `outcome:` in both files' frontmatter
- move its line from **Active** to **Archived** in `planning/README.md`.

This is done during `finishing-a-development-branch` (the `pr`/merge ref isn't known until then).

---

## Self-Review notes (for the executor)

- **Spec coverage:** structure scaffold + templates + deferred + CLAUDE.md (T1), 9-bundle migration with frontmatter (T2), README conventions+index + legacy relocation + `docs/` deletion (T3), verification incl. analyze/test-green proof of no code change (T4), promotion-at-merge note. `architecture/` deliberately deferred (in `deferred.md`).
- **No `git add -A`** anywhere — explicit paths only (`.claude/` hygiene).
- **Bodies move verbatim** — frontmatter is prepended, content is not rewritten; `git mv` keeps rename history.
- **`outcome` values are fixed** in the Task 2 table — not executor judgment.

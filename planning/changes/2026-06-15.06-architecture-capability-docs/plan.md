# architecture-capability-docs — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps
> use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bootstrap the `architecture/` truth-home — six capability docs plus an
index — and retire the "forthcoming" hedges that reference it.

**Spec:** [`design.md`](./design.md)

**Branch:** `docs/architecture-capability-docs`

**Commit strategy:** Per-task commits (one per capability doc, one for the
index, one for the housekeeping sweep).

---

## Conventions for every capability doc

This plan instantiates the **same skeleton** for each of the six capability
docs. Read it once here; each task supplies only the capability-specific
content.

- **No frontmatter.** The file starts with the `#` H1. The convention is
  explicit that `architecture/` files carry none.
- **Present tense, current state.** Describe what the code does *now*. Rationale
  and history live in the linked change bundles.
- **Code wins on conflict** with the archived `design.md`. Read the live code
  before writing; the archived spec supplies vocabulary and intent only.
- **Clickable refs.** Code map entries use `` `lib/path/file.dart:NN` `` form so
  they resolve in the editor. Verify each line number against the live file at
  write time (line numbers below are *starting hints*, not promises).

Skeleton (Markdown):

```markdown
# <Capability title>

## Purpose

<One line: what this capability is.>

## Behavior

<What it does today, from the user's view. 2-5 sentences or a short list.>

## Code map

- `lib/path/a.dart:NN` — <role>
- `lib/path/b.dart:NN` — <role>

## Invariants

- <Contract that must hold.>

## Known edges

- <Current limitation. Mirror the relevant deferred.md item as a one-line fact,
  no trigger detail.>

## History

Defined by: [<bundle-slug>](../planning/changes/<dir>/design.md)<, ...>
```

Per-doc verification, run before each commit:

```bash
# no frontmatter (first line must be the H1, not '---')
head -1 architecture/<file>.md | grep -q '^# ' && echo OK-no-frontmatter

# every lib/ ref in the doc resolves to a real file
grep -oE 'lib/[A-Za-z0-9_/]+\.dart' architecture/<file>.md | sort -u | while read f; do test -f "$f" && echo "OK $f" || echo "MISSING $f"; done
```

---

### Task 1: `habit-tracking.md`

**Files:**
- Create: `architecture/habit-tracking.md`

The core loop: create / edit / delete / check-off / reorder habits, persisted in
Drift.

- [ ] **Step 1: Read the sources**

  Read for current behavior (code wins): `lib/data/repositories/habit_repository.dart`,
  `lib/data/services/database/habit_dao.dart`,
  `lib/data/services/database/database.dart`, `lib/domain/reorder.dart`,
  `lib/domain/models/habit_summary.dart`, `lib/domain/models/habit_with_dates.dart`,
  `lib/ui/habit_list/habit_list_view_model.dart`,
  `lib/ui/habit_detail/habit_detail_view_model.dart`,
  `lib/ui/widgets/habit_dialogs.dart`.

  Read for intent: `planning/changes/2026-06-13.01-foundation/design.md`,
  `planning/changes/2026-06-15.01-architecture-refactor/design.md`,
  `planning/changes/2026-06-14.03-reorder-habits/design.md`.

- [ ] **Step 2: Write the doc**

  Instantiate the skeleton. Capability-specific content:

  - **Purpose:** The create/track/edit loop for habits and their daily
    completion records.
  - **Behavior:** Add a habit (name + color); check it off for a day (including
    retroactively from the detail heatmap); edit or delete it; drag to reorder
    the home list. State flows view → view-model → repository → DAO → Drift.
  - **Code map:** the files from Step 1, each with a one-line role
    (repository = public data API; DAO = queries; database = Drift schema;
    `reorder.dart` = pure ordering math; view-models = per-screen commands;
    `habit_dialogs.dart` = presentational add/edit form).
  - **Invariants:** habits carry an explicit integer sort order that
    `reorder.dart` keeps gap-free and stable; a completion is keyed by
    `(habitId, date-only)` so a day is either done or not (no partial /
    duplicate marks).
  - **Known edges:** mirror the `deferred.md` items that touch this capability —
    `TextEditingController` not disposed in `habit_dialogs.dart`.
  - **History:** foundation, architecture-refactor, reorder-habits bundles.

- [ ] **Step 3: Verify**

  Run the two verification snippets from *Conventions* with
  `<file>=habit-tracking`. Expected: `OK-no-frontmatter` and an `OK` line per
  `lib/` ref, no `MISSING`.

- [ ] **Step 4: Commit**

  ```bash
  git add architecture/habit-tracking.md
  git commit -m "docs(architecture): habit-tracking capability doc

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 2: `streaks-and-stats.md`

**Files:**
- Create: `architecture/streaks-and-stats.md`

Derived views over completion data: current streak, completion percentage, the
detail heatmap, and the recent-days strip.

- [ ] **Step 1: Read the sources**

  Code: `lib/domain/streak.dart`, `lib/domain/completion_stats.dart`,
  `lib/domain/heatmap.dart`, `lib/domain/recent_days.dart`, `lib/domain/dates.dart`,
  `lib/ui/widgets/heatmap_grid.dart`, `lib/ui/widgets/day_strip.dart`,
  `lib/ui/widgets/recent_days_list.dart`.
  Intent: `planning/changes/2026-06-13.02-heatmap-retroactive-editing/design.md`,
  `planning/changes/2026-06-13.01-foundation/design.md`.

- [ ] **Step 2: Write the doc**

  Capability-specific content:

  - **Purpose:** Pure functions that turn the set of completed dates into
    streaks, percentages, and calendar visualizations.
  - **Behavior:** detail screen shows current streak, completion %, a
    multi-week heatmap (tap a cell to toggle that day), and a recent-days strip.
  - **Code map:** the Step 1 files; stress that `domain/` here is pure
    (no Drift, no `BuildContext`) and the `ui/widgets/` files only render.
  - **Invariants:** state these from the live code —
    `currentStreak` counts consecutive completed days ending at today, or at
    yesterday when today is not yet done; a single missed day resets it to the
    count after the gap (`lib/domain/streak.dart:8`).
    `completionPercent` is computed over the span from habit creation to the
    last relevant day, inclusive (`lib/domain/completion_stats.dart:9`); confirm
    the exact window against the code before asserting it.
    All date math goes through `dates.dart` `dateOnly`/`previousDay` so time
    components never leak in.
  - **Known edges:** none currently tracked in `deferred.md` for this
    capability — state "none" rather than inventing one.
  - **History:** foundation, heatmap-retroactive-editing.

- [ ] **Step 3: Verify**

  Run the verification snippets with `<file>=streaks-and-stats`. Also re-read
  `lib/domain/streak.dart` and `lib/domain/completion_stats.dart` and confirm
  every Invariant matches the code exactly.

- [ ] **Step 4: Commit**

  ```bash
  git add architecture/streaks-and-stats.md
  git commit -m "docs(architecture): streaks-and-stats capability doc

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 3: `reminders.md`

**Files:**
- Create: `architecture/reminders.md`

Per-habit local notifications: schedule computation in `domain/`, OS delivery in
`data/services/`, app-lifecycle wiring in `ui/core/`.

- [ ] **Step 1: Read the sources**

  Code: `lib/domain/reminder_schedule.dart`,
  `lib/data/services/notification_service.dart`,
  `lib/ui/core/reminder_coordinator.dart`.
  Intent: `planning/changes/2026-06-14.02-reminders/design.md`.

- [ ] **Step 2: Write the doc**

  Capability-specific content:

  - **Purpose:** Fire a local notification at each habit's chosen reminder time.
  - **Behavior:** a habit can carry a reminder time; the coordinator
    (re)schedules notifications when habits change; tapping a notification opens
    the app.
  - **Code map:** `reminder_schedule.dart` = pure `computeReminderSchedule`
    producing `ScheduledReminder`s; `notification_service.dart` = thin wrapper
    over `flutter_local_notifications`; `reminder_coordinator.dart` = listens to
    habit state and reconciles scheduled notifications.
  - **Invariants:** scheduling is derived, not stored — the coordinator
    recomputes from current habits rather than tracking notification IDs by
    hand; a habit with no reminder time schedules nothing.
  - **Known edges:** mirror `deferred.md` — the Android notification *channel
    name* (`'Habit reminders'`) is hard-coded English, not localized.
  - **History:** reminders.

- [ ] **Step 3: Verify**

  Run the verification snippets with `<file>=reminders`.

- [ ] **Step 4: Commit**

  ```bash
  git add architecture/reminders.md
  git commit -m "docs(architecture): reminders capability doc

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 4: `backup-io.md`

**Files:**
- Create: `architecture/backup-io.md`

JSON export/import of all habit data with strict validation.

- [ ] **Step 1: Read the sources**

  Code: `lib/data/repositories/backup_repository.dart`,
  `lib/domain/backup_codec.dart`, `lib/domain/models/backup_data.dart`.
  Intent: `planning/changes/2026-06-14.01-export-import/design.md`.

- [ ] **Step 2: Write the doc**

  Capability-specific content:

  - **Purpose:** Export the full database to a JSON file and import it back,
    rejecting anything that is not a valid Habbits backup.
  - **Behavior:** Settings offers Export (writes + shares a JSON file) and
    Import (picks a file, validates, replaces data).
  - **Code map:** `backup_codec.dart` = pure `encodeBackup`/`decodeBackup` with
    `BackupFormatException`; `backup_data.dart` = the serialized shape;
    `backup_repository.dart` = bridges the codec to the live DB and file I/O.
  - **Invariants:** decode is strict — non-JSON, wrong shape, or a missing/invalid
    `exportedAt` each throw `BackupFormatException` rather than importing partial
    data (`lib/domain/backup_codec.dart:32`); the codec is pure (no DB, no
    filesystem), so it is unit-testable in isolation.
  - **Known edges:** mirror `deferred.md` — `SharePlus.share` passes no
    `sharePositionOrigin`, which crashes on iPad.
  - **History:** export-import.

- [ ] **Step 3: Verify**

  Run the verification snippets with `<file>=backup-io`.

- [ ] **Step 4: Commit**

  ```bash
  git add architecture/backup-io.md
  git commit -m "docs(architecture): backup-io capability doc

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 5: `i18n.md`

**Files:**
- Create: `architecture/i18n.md`

Full English + Russian localization via Flutter `gen-l10n`, with a user-facing
language switch.

- [ ] **Step 1: Read the sources**

  Code: `lib/l10n/app_localizations.dart` (+ `_en`/`_ru`),
  `lib/ui/core/locale_controller.dart`, the language switch in
  `lib/ui/settings/settings_screen.dart` /
  `lib/ui/settings/settings_view_model.dart`,
  and locale persistence in `lib/data/repositories/settings_repository.dart`.
  Intent: `planning/changes/2026-06-14.04-russian-language/design.md`.

- [ ] **Step 2: Write the doc**

  Capability-specific content:

  - **Purpose:** Render all UI copy and dates in the user's chosen language
    (English or Russian).
  - **Behavior:** Settings exposes a language choice; the app switches live;
    dates and plurals follow the active locale.
  - **Code map:** `l10n/` = generated `AppLocalizations` from ARB; the generated
    `*.g.dart` / `app_localizations*.dart` are committed; `locale_controller.dart`
    = holds and changes the active locale; `settings_repository.dart` persists
    it.
  - **Invariants:** no user-facing string is hard-coded in widgets — copy comes
    from `AppLocalizations`; Russian plurals use ICU plural categories, not
    English `count == 1` logic; date formatting is locale-aware.
  - **Known edges:** mirror `deferred.md` — the Android notification channel
    name is not localized (cross-link: also noted under [reminders](reminders.md)).
  - **History:** russian-language.

- [ ] **Step 3: Verify**

  Run the verification snippets with `<file>=i18n`. Note the l10n refs are
  `lib/l10n/*.dart` (generated) — confirm they resolve.

- [ ] **Step 4: Commit**

  ```bash
  git add architecture/i18n.md
  git commit -m "docs(architecture): i18n capability doc

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 6: `theming.md`

**Files:**
- Create: `architecture/theming.md`

App-wide light/dark theming and the activity-grid brand color.

- [ ] **Step 1: Read the sources**

  Code: `lib/ui/core/theme.dart`, theme-mode persistence in
  `lib/data/repositories/settings_repository.dart`, and the theme toggle in
  `lib/ui/settings/`.
  Intent: `planning/changes/2026-06-13.03-usability-v2/design.md`,
  `planning/changes/2026-06-15.02-app-icon-branding/design.md`.

- [ ] **Step 2: Write the doc**

  Capability-specific content:

  - **Purpose:** Define the app's light and dark `ThemeData` and persist the
    user's theme-mode choice.
  - **Behavior:** Settings offers light / dark / system; the choice persists
    across launches.
  - **Code map:** `theme.dart` = the `ThemeData` definitions + brand color;
    `settings_repository.dart` = persists theme mode (alongside locale, see
    [i18n](i18n.md)).
  - **Invariants:** widgets read colors/typography from `Theme.of(context)`,
    never hard-coded hex; theme mode and locale share one settings store.
  - **Known edges:** none currently tracked in `deferred.md` for theming —
    state "none".
  - **History:** usability-v2, app-icon-branding.

- [ ] **Step 3: Verify**

  Run the verification snippets with `<file>=theming`.

- [ ] **Step 4: Commit**

  ```bash
  git add architecture/theming.md
  git commit -m "docs(architecture): theming capability doc

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 7: `architecture/README.md` index

**Files:**
- Create: `architecture/README.md`

The one-screen entry point: what the app is, the layered map, and links to the
six capability docs.

- [ ] **Step 1: Write the index**

  Content:

  - **Title + 3-4 sentence overview:** local-first habit tracker (Flutter, iOS +
    Android, English + Russian); layered MVVM with Riverpod; Drift for storage;
    no backend.
  - **Layer map:** a short `ui → domain → data` description — `ui/` (screens,
    view-models, widgets) depends on `domain/` (pure logic + models) and `data/`
    (repositories over Drift DAO + platform services). Note that `domain/` is
    pure and independently testable.
  - **Capability table:** one row per doc with a one-line gloss:

    ```markdown
    | Capability | What it covers |
    |------------|----------------|
    | [Habit tracking](habit-tracking.md) | Create / edit / check-off / reorder habits |
    | [Streaks & stats](streaks-and-stats.md) | Streaks, completion %, heatmap, recent days |
    | [Reminders](reminders.md) | Per-habit local notifications |
    | [Backup I/O](backup-io.md) | JSON export / import with strict validation |
    | [i18n](i18n.md) | English + Russian localization |
    | [Theming](theming.md) | Light/dark themes + brand color |
    ```

  - **Pointer to planning:** one line — *history and rationale live in
    [`planning/`](../planning/README.md); these docs describe the present.*

- [ ] **Step 2: Verify links resolve**

  Run:

  ```bash
  grep -oE '\([a-z-]+\.md\)' architecture/README.md | tr -d '()' | while read f; do test -f "architecture/$f" && echo "OK $f" || echo "MISSING $f"; done
  ```

  Expected: an `OK` line for each of the six capability docs, no `MISSING`.

- [ ] **Step 3: Commit**

  ```bash
  git add architecture/README.md
  git commit -m "docs(architecture): truth-home index + overview

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 8: Retire the "forthcoming" hedges

**Files:**
- Modify: `planning/README.md`
- Modify: `CLAUDE.md`
- Modify: `planning/deferred.md`

The truth-home now exists; remove every reference that calls it forthcoming or
lists it as pending.

- [ ] **Step 1: `planning/README.md`**

  - In the intro paragraph, change "will live in `architecture/` at the repo
    root (forthcoming — see [`deferred.md`](deferred.md))." to state that it
    lives in [`architecture/`](../architecture/README.md) now.
  - In the "Two axes" bullet for `architecture/`, remove "*(Forthcoming for this
    repo.)*".
  - In the same section, remove the second "*(Forthcoming for this repo.)*"
    after the truth-home sentence if present.
  - In "Artifacts at a glance" / the shipping description, keep the "promote
    conclusions into the affected `architecture/<capability>.md`" wording — it
    now points at real files; no change needed beyond confirming it reads
    correctly.

- [ ] **Step 2: `CLAUDE.md`**

  In the project guide, change the line
  "The `architecture/` truth-home capability docs are forthcoming (tracked in
  `planning/deferred.md`)." to state that the `architecture/` capability docs
  exist at the repo root and are the living truth-home (one file per capability).

- [ ] **Step 3: `planning/deferred.md`**

  Remove the entire `**`architecture/` truth-home capability docs**` bullet
  (its lines through its `*Revisit when*` clause). Leave the other bullets
  untouched.

- [ ] **Step 4: Verify nothing still calls it forthcoming**

  Run:

  ```bash
  grep -rniE 'architecture/.*forthcoming|forthcoming.*architecture' planning/ CLAUDE.md; echo "exit: $?"
  grep -ni 'truth-home capability docs' planning/deferred.md; echo "deferred exit: $?"
  ```

  Expected: first grep prints nothing (exit 1); second prints nothing (the
  deferred item is gone).

- [ ] **Step 5: Confirm code untouched**

  Run: `git diff --name-only HEAD~7 -- lib test`
  Expected: no output — this change touched zero code files.

- [ ] **Step 6: Commit**

  ```bash
  git add planning/README.md CLAUDE.md planning/deferred.md
  git commit -m "docs: retire architecture/ forthcoming hedges; close deferred item

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

## Final verification

- [ ] **All six capability docs + index exist and are frontmatter-free:**

  ```bash
  ls architecture/*.md
  for f in architecture/*.md; do head -1 "$f" | grep -q '^# ' && echo "OK $f" || echo "FRONTMATTER? $f"; done
  ```

  Expected: 7 files; an `OK` line for each.

- [ ] **No broken `lib/` refs across all docs:**

  ```bash
  grep -rhoE 'lib/[A-Za-z0-9_/]+\.dart' architecture/ | sort -u | while read f; do test -f "$f" || echo "MISSING $f"; done
  ```

  Expected: no `MISSING` output.

- [ ] **Build still green (sanity, no code changed):**

  ```bash
  just lint && just test
  ```

  Expected: analyze clean, 115 tests pass.

- [ ] **Move the bundle to archived** once merged (per convention): set
  `status: shipped` + `pr:` + `outcome:` in `design.md`, move the folder to
  `planning/changes/`, and move its Index line from **Active** to
  **Archived** in `planning/README.md`.

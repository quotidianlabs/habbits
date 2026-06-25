# habit-summary-factory — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps
> use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the habit scalar composition into a `HabitSummary.from` factory
and thread one reactive `today` into every derived view.

**Spec:** [`design.md`](./design.md)

**Branch:** `feat/habit-summary-factory`

**Commit strategy:** Per-task commits.

---

### Task 1: Add the `HabitSummary.from` factory (test-first)

**Files:**
- Create: `test/domain/habit_summary_test.dart`
- Modify: `lib/domain/models/habit_summary.dart`

The pure factory that owns the scalar composition and normalization.

- [ ] **Step 1: Write the failing pure test**

  `test/domain/habit_summary_test.dart`, no Riverpod / no DB. Cover, from
  `HabitWithDates` fixtures + a `today`:
  - streak / `doneToday` / `completionPercent` together for a known date set;
  - empty completions → streak 0, `doneToday` false, `completionPercent` null;
  - **normalization contract:** inputs carrying time-of-day and a
    non-normalized `today` still yield correct `doneToday` and a day-only
    `dates` set.

  `flutter test test/domain/habit_summary_test.dart` — fails (no factory yet).

- [ ] **Step 2: Add the factory**

  Add `factory HabitSummary.from(HabitWithDates row, DateTime today)` per
  design §1: `dateOnly(today)`, normalize `row.dates` once, store the
  normalized set, compute scalars via `currentStreak` / `completionPercent`.
  Add imports: `dates.dart`, `streak.dart`, `completion_stats.dart`,
  `habit_with_dates.dart`.

  `flutter test test/domain/habit_summary_test.dart` — green.

- [ ] **Step 3: Commit**

  ```bash
  git add lib/domain/models/habit_summary.dart test/domain/habit_summary_test.dart
  git commit -m "feat: add HabitSummary.from factory owning scalar composition

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 2: Call the factory from the list view model

**Files:**
- Modify: `lib/ui/habit_list/habit_list_view_model.dart`
- Modify: `test/ui/habit_list/habit_list_view_model_test.dart`

Collapse the inline `map` to `HabitSummary.from(row, today)` and thin the VM
test.

- [ ] **Step 1: Replace the inline map**

  `habit_list_view_model.dart:21-32` → `[for (final row in rows)
  HabitSummary.from(row, today)]`. Drop now-unused imports (`streak.dart`,
  `completion_stats.dart`) if the file no longer references them directly.

- [ ] **Step 2: Thin the VM test**

  Keep wiring + reactivity (repo → factory → stream; re-emission on
  `currentDayProvider` change). Remove streak/percentage edge cases now owned by
  the pure test.

  `flutter test test/ui/habit_list/` — green.

- [ ] **Step 3: Commit**

  ```bash
  git add lib/ui/habit_list/habit_list_view_model.dart test/ui/habit_list/habit_list_view_model_test.dart
  git commit -m "refactor: build home summaries via HabitSummary.from

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 3: One reactive `today` in card + detail

**Files:**
- Modify: `lib/ui/habit_list/widgets/habit_card.dart`
- Modify: `lib/ui/habit_detail/habit_detail_screen.dart`
- Modify: `test/ui/habit_detail_screen_test.dart` (and/or list screen test)

Delete the two `dateOnly(DateTime.now())` calls; watch `currentDayProvider`.

- [ ] **Step 1: Rewire `habit_card`**

  `habit_card.dart:19` → `final today = ref.watch(currentDayProvider);`. Drop
  the now-unused `dates.dart` import if `dateOnly` is no longer referenced.

- [ ] **Step 2: Rewire `habit_detail_screen`**

  `habit_detail_screen.dart:28` → `final today =
  ref.watch(currentDayProvider);`. `buildHeatmap` and `RecentDaysList` now
  receive the reactive value.

- [ ] **Step 3: Add the midnight-advance screen test**

  Override `currentDayProvider`, render, advance the provided day past
  midnight, pump, assert the heatmap / strip re-render against the new day.

  `flutter test test/ui/` — green.

- [ ] **Step 4: Commit**

  ```bash
  git add lib/ui/habit_list/widgets/habit_card.dart lib/ui/habit_detail/habit_detail_screen.dart test/ui/
  git commit -m "fix: derive card strip and detail heatmap from currentDayProvider

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 4: Promote to architecture/ and verify

**Files:**
- Modify: `architecture/streaks-and-stats.md`
- Modify: `planning/changes/2026-06-24.01-habit-summary-factory/design.md` (frontmatter)

Hand-promote the truth-home prose in the same branch, then full verify.

- [ ] **Step 1: Update the capability doc**

  In `architecture/streaks-and-stats.md`: note that scalar composition is owned
  by `HabitSummary.from(HabitWithDates, today)`, and that the home card and
  detail screen derive their views from `currentDayProvider` (no wall-clock
  reads). Add the change to the History line.

- [ ] **Step 2: Full verify**

  `just lint` and `just test` — both green. Run `just index` if regenerating
  the change listing.

- [ ] **Step 3: Set frontmatter + commit**

  Set `status: shipped`, fill `pr` and `outcome` in `design.md` once the PR
  exists.

  ```bash
  git add architecture/streaks-and-stats.md planning/changes/2026-06-24.01-habit-summary-factory/
  git commit -m "docs: promote habit-summary-factory to architecture/

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---
status: draft
date: 2026-06-20
slug: live-current-day
spec: live-current-day
pr: null
---

# live-current-day — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recompute the home list's `today` on a live day-boundary signal
(midnight timer + app-resume) so streak / done-today / completion-% don't go
stale across midnight.

**Spec:** [`design.md`](./design.md)

**Branch:** `fix/live-current-day`

**Commit strategy:** Per-task commits.

---

### Task 1: `nextLocalMidnight` pure helper

**Files:**
- Modify: `lib/domain/dates.dart`
- Modify: `test/domain/dates_test.dart`

- [ ] **Step 1: Failing tests first.** Add `nextLocalMidnight` cases to
  `dates_test.dart`: returns next day 00:00; crosses month end (e.g. Jun 30 →
  Jul 1); crosses year end (Dec 31 → Jan 1). Run — fails (symbol undefined).

- [ ] **Step 2:** Add `nextLocalMidnight(DateTime now)` per `design.md` §1.

- [ ] **Step 3:** `flutter test test/domain/dates_test.dart` — green.

- [ ] **Step 4: Commit.**

  ```bash
  git add lib/domain/dates.dart test/domain/dates_test.dart
  git commit -m "feat(domain): nextLocalMidnight helper

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 2: `currentDayProvider`

**Files:**
- Create: `lib/ui/core/current_day.dart`
- Generated: `lib/ui/core/current_day.g.dart` (build_runner)

- [ ] **Step 1:** Write `CurrentDay` keep-alive Notifier per `design.md` §2
  (timer armed to `nextLocalMidnight`, `AppLifecycleListener.onResume` refresh,
  `ref.onDispose` cleanup, no-op when the day is unchanged).

- [ ] **Step 2:** `dart run build_runner build --delete-conflicting-outputs` to
  generate `current_day.g.dart`.

- [ ] **Step 3:** `flutter analyze` — clean.

- [ ] **Step 4: Commit.**

  ```bash
  git add lib/ui/core/current_day.dart lib/ui/core/current_day.g.dart
  git commit -m "feat(ui): currentDay provider ticking at local midnight

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 3: Home view model reads `currentDayProvider`

**Files:**
- Modify: `lib/ui/habit_list/habit_list_view_model.dart`
- Modify: `test/ui/habit_list/habit_list_view_model_test.dart`

- [ ] **Step 1: Failing test first.** In the VM test, override `currentDayProvider`
  with a fixed-day subclass. Seed a habit completed on day X. Assert `doneToday`
  is true when the override == X, and false when the override == X+1 (proves the
  VM anchors on the provider, not wall-clock `now`). Run — the X+1 case fails
  because the VM still uses `DateTime.now()`.

- [ ] **Step 2:** Replace `final today = dateOnly(DateTime.now());` with
  `final today = ref.watch(currentDayProvider);` and import the provider.

- [ ] **Step 3:** `flutter test test/ui/habit_list/habit_list_view_model_test.dart`
  — green (including existing tests).

- [ ] **Step 4: Commit.**

  ```bash
  git add lib/ui/habit_list/habit_list_view_model.dart test/ui/habit_list/habit_list_view_model_test.dart
  git commit -m "fix(ui): anchor home list today on the live currentDay provider

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 4: Promote to architecture docs + ship bookkeeping

**Files:**
- Modify: `architecture/streaks-and-stats.md`
- Modify: `planning/changes/2026-06-20.03-live-current-day/design.md` (frontmatter)
- Modify: `planning/changes/2026-06-20.03-live-current-day/plan.md` (frontmatter)
- Modify: `planning/deferred.md` (remove the shipped item)

- [ ] **Step 1:** Update `architecture/streaks-and-stats.md` per `design.md`
  (live `today` from `currentDayProvider`).

- [ ] **Step 2:** Remove the "Today goes stale across midnight" entry from
  `planning/deferred.md`.

- [ ] **Step 3:** `just test` (all green) and `just lint` (clean).

- [ ] **Step 4:** Set `status: shipped` + `pr` / `outcome` in `design.md`, `pr` in
  `plan.md` (PR number after the PR opens).

- [ ] **Step 5: Commit.**

  ```bash
  git add architecture/ planning/
  git commit -m "docs: promote live-current-day to architecture

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

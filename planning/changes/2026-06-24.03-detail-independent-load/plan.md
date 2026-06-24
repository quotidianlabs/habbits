---
status: draft
date: 2026-06-24
slug: detail-independent-load
spec: detail-independent-load
pr: null
---

# detail-independent-load — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps
> use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cut the detail view model's dependency on the list view model by
giving it a single-habit repository watch composed through `HabitSummary.from`.

**Spec:** [`design.md`](./design.md)

**Branch:** `feat/detail-independent-load`

**Commit strategy:** Per-task commits.

---

### Task 1: Single-habit watch in the DAO (test-first)

**Files:**
- Modify: `test/data/services/database/habit_dao_test.dart`
- Modify: `lib/data/services/database/habit_dao.dart`

A reactive single-habit query mirroring `watchHabitsWithDates`.

- [ ] **Step 1: Write the failing DAO test**

  In `habit_dao_test.dart`: create a habit, listen to `watchHabitWithDates(id)`;
  assert it emits the habit with an empty date set, re-emits with the date after
  `toggleCompletion`, and emits `null` after `deleteHabit`. Also assert
  `watchHabitWithDates(9999)` emits `null` for an absent id.

  `flutter test test/data/services/database/habit_dao_test.dart` — fails (method
  absent).

- [ ] **Step 2: Add `watchHabitWithDates`**

  Per design §1: filtered `habits ⋈ completions` join, grouped via `_group`,
  returning `grouped.isEmpty ? null : grouped.single`.

  Test green.

- [ ] **Step 3: Commit**

  ```bash
  git add lib/data/services/database/habit_dao.dart test/data/services/database/habit_dao_test.dart
  git commit -m "feat: add watchHabitWithDates single-habit DAO stream"
  ```

---

### Task 2: Expose `watchHabit` on the repository

**Files:**
- Modify: `lib/data/repositories/habit_repository.dart`
- Modify: `test/data/repositories/` (the existing habit-repository test, if one
  asserts the method surface; otherwise covered transitively by Task 3)

Thin forwarder keeping Drift out of `ui/`.

- [ ] **Step 1: Add the method**

  `Stream<HabitWithDates?> watchHabit(int id) => _dao.watchHabitWithDates(id);`

- [ ] **Step 2: Verify**

  `flutter test test/data/` green.

- [ ] **Step 3: Commit**

  ```bash
  git add lib/data/repositories/habit_repository.dart test/data/repositories/
  git commit -m "feat: expose watchHabit on HabitRepository"
  ```

---

### Task 3: Detail VM owns its stream (test-first)

**Files:**
- Modify: `test/ui/habit_detail/habit_detail_view_model_test.dart`
- Modify: `lib/ui/habit_detail/habit_detail_view_model.dart`
- Regenerate: `lib/ui/habit_detail/habit_detail_view_model.g.dart`

`build` becomes `Stream<HabitSummary?>` composing through `HabitSummary.from`;
the list-VM import is dropped.

- [ ] **Step 1: Rewrite the VM test (red)**

  Remove the `habit_list_view_model.dart` import and every `keep`-alive list
  subscription. Build the detail VM directly; assert it composes the summary for
  its id, re-emits on toggle, yields `null` for a missing id, and re-emits when
  `currentDayProvider` advances (reuse a `_FixedCurrentDay`-style override).
  Reads await the detail provider's `AsyncValue`.

  Run — fails (build still returns sync `HabitSummary?`, still list-derived).

- [ ] **Step 2: Rewrite `build`**

  Per design §3: `Stream<HabitSummary?> build(int habitId)` watching
  `habitRepositoryProvider` + `currentDayProvider`, mapping `repo.watchHabit` →
  `HabitSummary.from`. Drop the list-VM import. Add the `current_day.dart` import.

- [ ] **Step 3: Regenerate + green**

  ```bash
  dart run build_runner build --delete-conflicting-outputs
  flutter test test/ui/habit_detail/
  ```

- [ ] **Step 4: Commit**

  ```bash
  git add lib/ui/habit_detail/habit_detail_view_model.dart lib/ui/habit_detail/habit_detail_view_model.g.dart test/ui/habit_detail/habit_detail_view_model_test.dart
  git commit -m "refactor: detail VM watches its own habit, not the list VM"
  ```

---

### Task 4: Detail screen reads the AsyncValue

**Files:**
- Modify: `lib/ui/habit_detail/habit_detail_screen.dart`
- Modify: `test/ui/habit_detail_screen_test.dart` (only if a case needs adjusting)

Surface the stream's value without changing the spinner branch.

- [ ] **Step 1: Read `.valueOrNull`**

  `habit_detail_screen.dart:18` →
  `final summary = ref.watch(habitDetailViewModelProvider(habitId)).valueOrNull;`
  Leave the `if (summary == null) → spinner` branch as-is.

- [ ] **Step 2: Verify the screen tests**

  `flutter test test/ui/habit_detail_screen_test.dart` — green; confirm the
  loading frame still shows the spinner and resolves. Adjust only if a case
  read the provider's value directly.

- [ ] **Step 3: Commit**

  ```bash
  git add lib/ui/habit_detail/habit_detail_screen.dart test/ui/habit_detail_screen_test.dart
  git commit -m "refactor: detail screen reads habit summary from AsyncValue"
  ```

---

### Task 5: Promote to architecture/ and verify

**Files:**
- Modify: `architecture/habit-tracking.md`
- Modify: `planning/changes/2026-06-24.03-detail-independent-load/design.md` (frontmatter)

- [ ] **Step 1: Update the capability doc**

  In `architecture/habit-tracking.md`: update the detail-VM code-map line — it
  no longer derives from the list VM but watches its own habit via
  `HabitRepository.watchHabit`. Add the new repo/DAO watch to the relevant
  lines and the History line.

- [ ] **Step 2: Full verify**

  `just lint` and `just test` — both green. `just index` if regenerating the
  listing.

- [ ] **Step 3: Set frontmatter + commit**

  Set `status: shipped`, fill `pr` and `outcome` once the PR exists.

  ```bash
  git add architecture/habit-tracking.md planning/changes/2026-06-24.03-detail-independent-load/
  git commit -m "docs: promote detail-independent-load to architecture/"
  ```

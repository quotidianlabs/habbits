---
status: draft
date: 2026-06-20
slug: harden-toggle-and-import
spec: harden-toggle-and-import
pr: 13
---

# harden-toggle-and-import — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the completion-toggle and backup-import write paths crash-proof:
atomic/idempotent `toggleCompletion`, format-validated `reminderTime` on import,
and de-duplicated completion dates on import.

**Spec:** [`design.md`](./design.md)

**Branch:** `fix/harden-toggle-and-import`

**Commit strategy:** Per-task commits (each task is an independent fix with its
own test).

---

### Task 1: Make `toggleCompletion` atomic and idempotent under concurrency

**Files:**
- Modify: `lib/data/services/database/habit_dao.dart`
- Modify: `test/data/services/database/habit_dao_test.dart`

Wrap the read + insert/delete in a `transaction()` so two concurrent toggles for
the same `(habitId, date)` serialize and net to the intended state instead of
throwing a `UNIQUE constraint failed` exception.

- [ ] **Step 1: Failing test first.**

  Add to `habit_dao_test.dart`: create a habit, then fire two toggles
  concurrently without awaiting between them:

  ```dart
  test('toggleCompletion tolerates concurrent double-toggle without throwing', () async {
    final id = await dao.createHabit(name: 'Read', color: 1);
    final date = DateTime(2026, 6, 20);
    await Future.wait([
      dao.toggleCompletion(id, date),
      dao.toggleCompletion(id, date),
    ]);
    // Two toggles net to empty; the key invariant is: no exception thrown.
    final rows = await dao.watchHabitsWithDates().first;
    expect(rows.single.dates, isEmpty);
  });
  ```

  Run `flutter test test/data/services/database/habit_dao_test.dart` — expect it
  to fail with a `SqliteException` (UNIQUE constraint) on the current code.

- [ ] **Step 2: Wrap the body in a transaction.**

  In `habit_dao.dart`, change `toggleCompletion` to run its existing read/branch
  inside `transaction(() async { … })` (logic unchanged). Keep the doc comment.

- [ ] **Step 3: Test passes.**

  `flutter test test/data/services/database/habit_dao_test.dart` — green,
  including the existing "on then off nets to empty" idempotency test.

- [ ] **Step 4: Commit.**

  ```bash
  git add lib/data/services/database/habit_dao.dart test/data/services/database/habit_dao_test.dart
  git commit -m "fix(data): make toggleCompletion atomic to survive double-tap

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 2: Validate `reminderTime` format on backup import

**Files:**
- Modify: `lib/domain/backup_codec.dart`
- Modify: `test/domain/backup_codec_test.dart`

Reject any imported `reminderTime` that is not strict `HH:mm`, closing the path
that lets a malformed value crash `computeReminderSchedule` later.

- [ ] **Step 1: Failing test first.**

  Add a test asserting a backup with `reminderTime: "9am"` (and `""`, `"99:99"`)
  throws `BackupFormatException`, and that `"08:30"` / absent reminder decode
  cleanly. Run it — expect the `"9am"` case to currently pass decode (no throw),
  so the test fails.

- [ ] **Step 2: Add `_isValidHhmm` and tighten `_decodeHabit`.**

  Add the helper and the `!_isValidHhmm(reminder)` check per the spec. `null`
  stays valid.

- [ ] **Step 3: Test passes.**

  `flutter test test/domain/backup_codec_test.dart` — green.

- [ ] **Step 4: Commit.**

  ```bash
  git add lib/domain/backup_codec.dart test/domain/backup_codec_test.dart
  git commit -m "fix(domain): reject malformed reminderTime on backup import

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 3: De-duplicate completion dates on backup import

**Files:**
- Modify: `lib/domain/backup_codec.dart`
- Modify: `test/domain/backup_codec_test.dart`

Collapse exact-duplicate completion dates so a duplicated date no longer aborts
the whole import with a unique-constraint failure.

- [ ] **Step 1: Failing test first.**

  Add a test: decode a backup whose habit lists the same valid date twice →
  expect a single occurrence; then feed it through `importReplace` (in-memory DB)
  and assert no exception and the date appears once. Run it — expect the import to
  currently throw a `SqliteException`.

- [ ] **Step 2: Add the `seen` set in `_decodeHabit`.**

  Dedup valid dates per the spec; keep throwing on genuinely invalid dates.

- [ ] **Step 3: Test passes.**

  `flutter test test/domain/backup_codec_test.dart` — green.

- [ ] **Step 4: Commit.**

  ```bash
  git add lib/domain/backup_codec.dart test/domain/backup_codec_test.dart
  git commit -m "fix(domain): de-duplicate completion dates on backup import

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 4: Promote to architecture docs + ship bookkeeping

**Files:**
- Modify: `architecture/backup-io.md`
- Modify: `architecture/habit-tracking.md`
- Modify: `planning/changes/2026-06-20.01-harden-toggle-and-import/design.md` (frontmatter)
- Modify: `planning/changes/2026-06-20.01-harden-toggle-and-import/plan.md` (frontmatter)

- [ ] **Step 1: Update the truth home.**

  In `backup-io.md`, note import format-validates `reminderTime` and de-duplicates
  completion dates. In `habit-tracking.md`, note `toggleCompletion` is
  transactional/idempotent under concurrency.

- [ ] **Step 2: Full suite + lint.**

  `just test` (all tests green) and `just lint` — clean.

- [ ] **Step 3: Set ship status.**

  Set `status: shipped` and fill `pr` / `outcome` in `design.md`, and `pr` in
  `plan.md`, in the branch (per the planning convention — no post-merge step).

- [ ] **Step 4: Commit.**

  ```bash
  git add architecture/ planning/changes/2026-06-20.01-harden-toggle-and-import/
  git commit -m "docs: promote harden-toggle-and-import to architecture

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

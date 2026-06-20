---
status: draft
date: 2026-06-20
slug: harden-reminder-sync
spec: harden-reminder-sync
pr: null
---

# harden-reminder-sync — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Serialize + guard `ReminderCoordinator._sync`, make it best-effort, and
schedule reminders by wall-clock instant — with the first coordinator/service
tests.

**Spec:** [`design.md`](./design.md)  ·  **Branch:** `fix/harden-reminder-sync`

**Commit strategy:** Per-task commits.

---

### Task 1: Schedule by wall-clock instant + DST test

**Files:** `lib/data/services/notification_service.dart`,
`test/data/services/notification_service_test.dart` (new)

- [ ] **Step 1: Failing test first.** New test sets a DST zone and asserts
  `instantFor(DateTime(2026, 3, 9, 9, 0))` and `instantFor(DateTime(2026, 3, 7, 9, 0))`
  both have `.hour == 9` and `.location == tz.local`. Fails (symbol missing).
- [ ] **Step 2:** Add `@visibleForTesting tz.TZDateTime instantFor(DateTime)` and
  use it in `syncSchedule` in place of `tz.TZDateTime.from`.
- [ ] **Step 3:** `flutter test test/data/services/notification_service_test.dart` — green.
- [ ] **Step 4: Commit** (`fix(data): schedule reminders by local wall-clock instant`).

---

### Task 2: Serialize + guard `_sync`

**Files:** `lib/ui/core/reminder_coordinator.dart`,
`test/ui/core/reminder_coordinator_test.dart` (new)

- [ ] **Step 1: Failing tests first.** Add `FakeNotificationService` (records
  `syncSchedule`, exposes a controllable in-flight `Completer`, a concurrency
  counter, and an optional throw). Mount `ReminderCoordinator` with an in-memory
  DB + overridden `notificationServiceProvider`.
  - Re-entrancy: hold sync #1, trigger sync #2 via a habit toggle, release;
    assert max concurrency == 1 and a coalesced second `syncSchedule` ran.
  - Error: make `syncSchedule` throw; assert no exception escapes.
  Run — fails (current code interleaves / rethrows).
- [ ] **Step 2:** Refactor `_sync` into the guarded form + `_runSync()` per
  `design.md` §1.
- [ ] **Step 3:** `flutter test test/ui/core/reminder_coordinator_test.dart` — green.
- [ ] **Step 4: Commit** (`fix(ui): serialize reminder syncs and make them best-effort`).

---

### Task 3: Promote docs + ship bookkeeping

**Files:** `architecture/reminders.md`, `planning/deferred.md`, bundle frontmatter.

- [ ] **Step 1:** Update `architecture/reminders.md` (serialized + best-effort
  `_sync`; wall-clock-instant scheduling). 
- [ ] **Step 2:** Remove the shipped items from `deferred.md` (#5, #5b try/catch,
  #4 DST construction; keep the timezone-change-resync edge).
- [ ] **Step 3:** `just test` + `just lint` — green/clean.
- [ ] **Step 4:** Ship frontmatter (`status: shipped`, `pr`, `outcome`).
- [ ] **Step 5: Commit** (`docs: promote harden-reminder-sync to architecture`).

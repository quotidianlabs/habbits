# reminder-sync-controller — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps
> use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move reminder-sync policy into a plain-Dart `ReminderSync` controller
and shrink `ReminderCoordinator` to a lifecycle adapter, without changing
behavior.

**Spec:** [`design.md`](./design.md)

**Branch:** `feat/reminder-sync-controller`

**Commit strategy:** Per-task commits.

---

### Task 1: `ReminderSync` controller (test-first)

**Files:**
- Create: `test/ui/core/reminder_sync_test.dart`
- Create: `lib/ui/core/reminder_sync.dart`

The policy engine: coalescing, permission gate, sync()/onResume() sequencing.

- [ ] **Step 1: Write the failing controller test**

  `reminder_sync_test.dart`, no widget pumping. A fake `NotificationService`
  (recording call order + counts; togglable throw/permission). Cover design
  §Testing: request-before-check ordering, gate-fires-once, onResume
  refresh→recheck→resync order, coalescing serialization, best-effort swallow,
  `isActive() == false` suppresses report/schedule, `readEnabledHabits() == null`
  skips entirely.

  `flutter test test/ui/core/reminder_sync_test.dart` — fails (no `ReminderSync`).

- [ ] **Step 2: Implement `ReminderSync`**

  Per design §1: constructor injecting `service`, `readEnabledHabits`,
  `readBody`, `reportPermission`, `isActive`, `now`. `_runner` +
  `_permissionAsked`; `sync()`, `onResume()`, `_runSyncSafe`, `_runSync`,
  `_updatePermission` mirroring today's logic with `isActive()` for the two
  `mounted` guards.

  Test green.

- [ ] **Step 3: Commit**

  ```bash
  git add lib/ui/core/reminder_sync.dart test/ui/core/reminder_sync_test.dart
  git commit -m "feat: add ReminderSync policy controller"
  ```

---

### Task 2: Shrink `ReminderCoordinator` to a lifecycle adapter

**Files:**
- Modify: `lib/ui/core/reminder_coordinator.dart`

Delete the policy from the State; build + wire the controller.

- [ ] **Step 1: Rewrite the State**

  Per design §2: `initState` constructs `ReminderSync` with closures over
  `ref`/`context`, then wires `ref.listenManual` (habit list + locale) →
  `_sync.sync()`, `AppLifecycleListener(onResume: _sync.onResume)`, and a
  post-frame `_sync.sync()`. Remove `_runner`, `_permissionAsked`, and the
  `_sync`/`_resyncWithTimeZone`/`_runSync`/`_updatePermission` methods. `dispose`
  keeps disposing `_lifecycle`. Drop now-unused imports
  (`coalescing_runner.dart` moves to the controller;
  `domain/reminder_schedule.dart` is still needed for `ReminderHabit`).

- [ ] **Step 2: Verify the widget tests still pass (unchanged)**

  `flutter test test/ui/core/reminder_coordinator_test.dart` — green, no edits
  to the test file (behavior preserved is the whole point).

- [ ] **Step 3: Commit**

  ```bash
  git add lib/ui/core/reminder_coordinator.dart
  git commit -m "refactor: ReminderCoordinator delegates policy to ReminderSync"
  ```

---

### Task 3: Promote to architecture/ and verify

**Files:**
- Modify: `architecture/reminders.md`
- Modify: `planning/changes/2026-06-24.04-reminder-sync-controller/design.md` (frontmatter)

- [ ] **Step 1: Update the capability doc**

  In `architecture/reminders.md`: note that the sync policy (coalescing,
  permission gate, ordering) lives in `ReminderSync` (`lib/ui/core/reminder_sync.dart`)
  and the coordinator widget is a lifecycle adapter. Update the relevant code-map
  line(s) and the History line.

- [ ] **Step 2: Full verify**

  `just lint` and `just test` — both green. `just index` if regenerating.

- [ ] **Step 3: Set frontmatter + commit**

  Set `status: shipped`, fill `pr` and `outcome` once the PR exists.

  ```bash
  git add architecture/reminders.md planning/changes/2026-06-24.04-reminder-sync-controller/
  git commit -m "docs: promote reminder-sync-controller to architecture/"
  ```

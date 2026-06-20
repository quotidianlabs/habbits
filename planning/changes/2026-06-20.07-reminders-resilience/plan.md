---
status: draft
date: 2026-06-20
slug: reminders-resilience
spec: reminders-resilience
pr: null
---

# reminders-resilience — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans.
> Checkbox (`- [ ]`) steps.

**Goal:** Warn on denied notification permission, refresh `tz.local` on resume,
and test removed-reminder cleanup.

**Spec:** [`design.md`](./design.md)  ·  **Branch:** `fix/reminders-resilience`

**Commit strategy:** Per-task commits.

---

### Task 1: NotificationService `hasPermission()` + `refreshTimeZone()`

**Files:** `lib/data/services/notification_service.dart`

- [ ] Add `hasPermission()` (checkPermissions / areNotificationsEnabled, default true).
- [ ] Add `refreshTimeZone()`; call it from `init()` in place of the inline tz set.
- [ ] `flutter analyze` clean. (Behavior covered via coordinator tests in Task 2.)
- [ ] Commit.

---

### Task 2: Permission provider + coordinator wiring + tests

**Files:** `lib/ui/core/notification_permission.dart` (new, + generated),
`lib/ui/core/reminder_coordinator.dart`, `test/ui/core/reminder_coordinator_test.dart`

- [ ] **Failing tests first** in `reminder_coordinator_test.dart`: extend the fake
  with `hasPermission` (configurable) + `refreshTimeZone` (counter); use an
  `UncontrolledProviderScope` so the test can read providers.
  - denied permission → `notificationPermissionProvider == false`.
  - removing a habit's reminder → next `syncSchedule` excludes it.
  - resume (inactive→resumed) → `refreshTimeZone` called.
- [ ] Add `NotificationPermission` notifier (`bool?`, `set`); `build_runner`.
- [ ] Wire `_runSync` to set the provider; switch `onResume` to `_resyncWithTimeZone`.
- [ ] Tests green.
- [ ] Commit.

---

### Task 3: Settings "notifications off" warning + i18n

**Files:** `lib/l10n/app_en.arb`, `app_ru.arb` (+ generated),
`lib/ui/settings/settings_screen.dart`, `test/ui/settings_screen_test.dart`

- [ ] **Failing test first**: override `notificationPermissionProvider`=false with
  a reminder habit → `notifications-off-warning` present; true/null → absent.
- [ ] Add `notificationsOffTitle`/`Body` ARB (en/ru); `gen-l10n`.
- [ ] Add the warning `Consumer` tile.
- [ ] Tests green.
- [ ] Commit.

---

### Task 4: Promote docs + ship bookkeeping

**Files:** `architecture/reminders.md`, `planning/deferred.md`, bundle frontmatter.

- [ ] Update `reminders.md` (permission status + resume tz refresh).
- [ ] Trim `deferred.md` (leave open-OS-settings + broadcast-listener follow-ups).
- [ ] `just test` + `just lint`.
- [ ] Ship frontmatter; commit.

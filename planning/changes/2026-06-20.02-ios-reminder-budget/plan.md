# ios-reminder-budget — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `computeReminderSchedule` hard-cap at the iOS 64-notification
budget (soonest-win), and warn in Settings when reminder-enabled habits exceed it.

**Spec:** [`design.md`](./design.md)

**Branch:** `fix/ios-reminder-budget`

**Commit strategy:** Per-task commits.

---

### Task 1: Chronological cap in `computeReminderSchedule`

**Files:**
- Modify: `lib/domain/reminder_schedule.dart`
- Modify: `test/domain/reminder_schedule_test.dart`

Generate all candidate reminders, sort by fire time, keep the soonest `iosBudget`.
Add `kIosNotificationBudget` const.

- [ ] **Step 1: Failing tests first.**

  Add two tests using the injectable params:

  ```dart
  test('total never exceeds the iOS budget when habits overflow it', () {
    final habits = [for (var i = 1; i <= 5; i++) habit(i, '20:00')];
    final s = computeReminderSchedule(habits, now, iosBudget: 3, maxBuffer: 14);
    expect(s.length, 3);
  });

  test('over budget, the soonest reminders win', () {
    // distinct future times today; maxBuffer 1 => one candidate per habit.
    final habits = [
      habit(1, '11:00'),
      habit(2, '12:00'),
      habit(3, '13:00'),
    ];
    final s = computeReminderSchedule(habits, now, iosBudget: 2, maxBuffer: 1);
    expect(s.map((r) => r.habitId), [1, 2]); // 11:00 and 12:00 beat 13:00
  });
  ```

  Run `flutter test test/domain/reminder_schedule_test.dart` — the overflow test
  fails (current code returns 5), the soonest test fails (current grouping/clamp).

- [ ] **Step 2: Rewrite the function** per `design.md` §1 (const + generate-all +
  sort + truncate).

- [ ] **Step 3: Tests pass.**

  `flutter test test/domain/reminder_schedule_test.dart` — green, **including all
  6 pre-existing tests** (behavior preservation for ≤ budget).

- [ ] **Step 4: Commit.**

  ```bash
  git add lib/domain/reminder_schedule.dart test/domain/reminder_schedule_test.dart
  git commit -m "fix(domain): hard-cap reminder schedule at the iOS notification budget

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 2: i18n strings for the over-budget warning

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_ru.arb`

Add `reminderLimitTitle` and `reminderLimitBody` ({count} int placeholder) per
`design.md` §3.

- [ ] **Step 1: Add the two keys** to `app_en.arb` (template, with `@reminderLimitBody`
  placeholder metadata) and `app_ru.arb`.

- [ ] **Step 2: Regenerate localizations.**

  `flutter gen-l10n` (or `flutter pub get` / build — confirm `AppLocalizations`
  exposes `reminderLimitTitle` and `reminderLimitBody(int)`).

- [ ] **Step 3: Commit.**

  ```bash
  git add lib/l10n/app_en.arb lib/l10n/app_ru.arb lib/l10n/app_localizations*.dart
  git commit -m "i18n: strings for the reminder over-budget warning (en/ru)

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 3: Settings over-budget warning tile

**Files:**
- Modify: `lib/ui/settings/settings_screen.dart`
- Modify: `test/ui/settings_screen_test.dart`

Add the `Consumer` warning tile per `design.md` §2.

- [ ] **Step 1: Failing test first.**

  In `settings_screen_test.dart`, override `habitListViewModelProvider` with
  `kIosNotificationBudget + 1` reminder-enabled summaries and assert the
  `reminder-budget-warning` tile is present; with a below-budget count assert it
  is absent. (Import `kIosNotificationBudget` from `reminder_schedule.dart`.)

  Run `flutter test test/ui/settings_screen_test.dart` — the present-case fails.

- [ ] **Step 2: Add the warning `Consumer`** as the first child of the Settings
  `ListView`, importing `kIosNotificationBudget` and `habitListViewModelProvider`.

- [ ] **Step 3: Tests pass.**

  `flutter test test/ui/settings_screen_test.dart` — green.

- [ ] **Step 4: Commit.**

  ```bash
  git add lib/ui/settings/settings_screen.dart test/ui/settings_screen_test.dart
  git commit -m "feat(settings): warn when reminders exceed the notification budget

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 4: Promote to architecture docs + ship bookkeeping

**Files:**
- Modify: `architecture/reminders.md`
- Modify: `planning/changes/2026-06-20.02-ios-reminder-budget/design.md` (frontmatter)
- Modify: `planning/changes/2026-06-20.02-ios-reminder-budget/plan.md` (frontmatter)
- Modify: `planning/deferred.md` (remove the now-shipped item)

- [ ] **Step 1: Update `architecture/reminders.md`** — chronological-cap behavior,
  hard `iosBudget` cap invariant, Settings over-budget warning, and the
  64+-habits known-edge.

- [ ] **Step 2: Remove the shipped item** from `planning/deferred.md` (the iOS
  notification-budget overflow entry).

- [ ] **Step 3: Full suite + lint.**

  `just test` (all green) and `just lint` (clean).

- [ ] **Step 4: Ship bookkeeping.**

  Set `status: shipped` + `pr` / `outcome` in `design.md`, `pr` in `plan.md`
  (PR number filled after the PR opens, per the planning convention).

- [ ] **Step 5: Commit.**

  ```bash
  git add architecture/ planning/
  git commit -m "docs: promote ios-reminder-budget to architecture

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

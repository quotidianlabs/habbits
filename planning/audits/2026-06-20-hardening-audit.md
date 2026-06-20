# Audit: Hardening sweep — bug-hunt + coverage

**Date:** 2026-06-20
**Scope:** Whole codebase (`lib/domain`, `lib/data`, `lib/ui`, `lib/l10n`), read-only.
**Method:** 9 finder agents (one per layer/risk-area, reading whole files) →
2 independent adversarial skeptics per finding (instructed to refute, default to
"not a bug") → synthesis. 32 findings raised → **12 confirmed**, **4 disputed**
(1 of 2 votes), **16 rejected**.

This audit spawns fix changes. The first is
[`changes/2026-06-20.01-harden-toggle-and-import`](../changes/2026-06-20.01-harden-toggle-and-import/)
(confirmed items 1, 2, 6). Remaining items are tracked below and in
[`deferred.md`](../deferred.md).

---

## Confirmed (12 findings → 8 root causes)

### 🔴 High

**1. `toggleCompletion` read-then-write is not atomic → double-tap crashes**
`habit_dao.dart:67` does `getSingleOrNull` then a separate insert/delete with no
transaction; `Completions` enforces unique `{habitId, localDate}`. The home
checkbox (`habit_card.dart:41`) and detail screen call it fire-and-forget with no
`await`/disable. Two fast taps both read "absent," both insert, the second throws
an uncaught `SqliteException`. *(3 findings: data-dao, ui-state, coverage.)*
→ **Fix in `harden-toggle-and-import`.**

**2. Malformed `reminderTime` from a backup crashes reminder scheduling app-wide**
`backup_codec.dart:82` validates `reminderTime` only as `is String`, never the
`HH:mm` format (unlike completion dates, which use `_isValidIsoDate`). A value
like `"9am"`/`""`/`"99:99"` imports successfully, then `reminder_schedule.dart:42`
and `habit_detail_screen.dart:138` do unguarded `int.parse` → `FormatException`
on every reminder sync, breaking notifications for *all* habits. *(3 findings:
dates-boundaries, backup-io, reminders.)* → **Fix in `harden-toggle-and-import`.**

**3. iOS 64-notification cap exceeded at 65+ reminder habits**
`reminder_schedule.dart:38`: `(iosBudget ~/ len).clamp(1, …)` — the lower clamp
of 1 defeats the budget, so 65 enabled habits schedule 65 notifications and iOS
silently drops the tail. *(2 findings: reminders, coverage.)*
→ **Deferred.** Fix: cap total to `iosBudget`, prefer soonest-firing.

**4. "Today" goes stale across midnight**
`habit_list_view_model.dart:20` computes `today` inside the Drift stream callback,
which only emits on DB writes — no midnight timer, no `onResume` refresh. App left
open overnight shows yesterday's streak/checkbox until the next write. *Skeptics
split high/medium: it's self-healing on the next tap and never writes the wrong
date (`toggleToday` recomputes `now`).* → **Deferred.** Fix: a `currentDay`
provider that ticks at local midnight.

### 🟡 Medium

**5. `ReminderCoordinator._sync` has no re-entrancy guard**
`reminder_coordinator.dart:41` — fired from 4 sources (habit-list listen, locale
listen, `onResume`, post-frame). Overlapping async runs race on `cancelAll()` →
final OS notification set doesn't match state. → **Deferred.** Fix: serialize /
debounce.

**6. Duplicate completion date in a backup → opaque `SqliteException`**
`backup_codec.dart:97` appends completions without dedup; `importReplace` then hits
the unique key and the whole import aborts (transaction rolls back — atomicity is
fine, but the error is opaque and the data is trivially salvageable).
→ **Fix in `harden-toggle-and-import`.**

**7. Reminder coverage gaps**
No tests for the budget overflow (item 3), the `TZDateTime.from` DST conversion,
cancel-then-reschedule (stale-notification) sequencing, permission denial, or
malformed-time parsing. The risky reminder logic is essentially unverified.
→ **Deferred.**

### 🟢 Low

**8. Heatmap month label off by up to a column**
`heatmap_grid.dart:42` keys the month label off the column's Monday, not the
column containing the 1st; when a month starts Tue–Sun the label lands one column
late. → **Deferred.**

---

## Disputed (1 of 2 votes — needs a human call)

- **DST / timezone wall-clock drift** (`notification_service.dart:84`): fire time
  is a VM-local `DateTime` re-expressed via `TZDateTime.from`, which preserves the
  *instant*, not the wall-clock. 02:30 reminders drift on spring-forward; and
  `tz.local` is set once at `init()`, so traveling across zones leaves stale
  instants until the next sync. Skeptics split on real-world reachability.
- **`_sync` has no `try/catch`** (`reminder_coordinator.dart:56`): a plugin
  failure becomes an unhandled async error rather than a best-effort no-op.
- **`'Habbits backup'` share subject is hard-coded English**
  (`backup_repository.dart:28`): bypasses l10n; Russian users get an English
  subject. Not currently in `deferred.md`.

## Rejected (notable)

Most rejections were coverage-gap items the skeptics declined to count as
"reachable bugs" — the gaps are still real, just not crashes. Two worth knowing:

- A finder reported the **backup test-file naming inversion** that `deferred.md`
  documents; a skeptic rejected it, claiming the names are *not* actually swapped.
  The `deferred.md` note may be stale — worth a manual confirm before acting on it.
- The **iPad `share_plus` popover anchor** and **Android channel-name i18n** items
  were surfaced and then set aside as already-documented known edges (both already
  in `deferred.md`).

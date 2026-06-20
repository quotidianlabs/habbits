---
status: draft
date: 2026-06-20
slug: harden-toggle-and-import
summary: Make the completion-toggle and backup-import write paths crash-proof.
supersedes: null
superseded_by: null
pr: null
outcome: null
---

# Design: Harden the toggle and backup-import write paths

## Summary

Three confirmed crash bugs from the [2026-06-20 hardening
audit](../../audits/2026-06-20-hardening-audit.md) share one shape — a write path
that trusts its input and hits the `Completions {habitId, localDate}` unique key
or an unguarded `int.parse`. This change makes all three robust:

1. **`toggleCompletion` becomes atomic + idempotent** so a rapid double-tap can no
   longer throw a `UNIQUE constraint failed` `SqliteException`.
2. **Backup import validates `reminderTime` format** so a hand-edited or
   corrupted file can no longer smuggle a non-`HH:mm` string that later crashes
   reminder scheduling app-wide.
3. **Backup import de-duplicates completion dates** so a file listing the same
   date twice for a habit no longer aborts the whole import with an opaque DB
   error.

All three are write-path hardening with shared test infrastructure (in-memory
Drift DB + codec unit tests), which is why they ship together.

## Motivation

From the audit, each confirmed and adversarially verified:

- **Double-tap crash (item 1, High).** `HabitDao.toggleCompletion`
  (`habit_dao.dart:67`) does `getSingleOrNull` then a *separate* insert with no
  enclosing transaction. The home checkbox (`habit_card.dart:41`) fires it without
  `await` and the checkbox only flips after the watch stream re-emits, so two fast
  taps both read "absent" and both insert `(habitId, today)` — the second violates
  the unique key and surfaces as an uncaught exception. Leaving a habit tracker
  unguarded against a double-tap on its single most-used control is the highest
  crash risk in the app.
- **Malformed `reminderTime` (item 2, High).** `decodeBackup`
  (`backup_codec.dart:82`) checks `reminderTime` only as `is String`, never its
  format — unlike completion dates, which already go through `_isValidIsoDate`.
  An imported `"9am"`/`""`/`"99:99"` is written verbatim, then
  `computeReminderSchedule` (`reminder_schedule.dart:42`) does
  `int.parse(parts[0])` with no guard → `FormatException` on the next reminder
  sync, breaking notifications for *every* habit until the bad value is removed.
- **Duplicate completion dates (item 6, Medium).** `_decodeHabit`
  (`backup_codec.dart:97`) appends every date without de-duplicating; a file with
  the same date twice for one habit makes `importReplace` hit the unique key and
  abort the entire import (the transaction correctly rolls back, but the failure
  is opaque and the data is trivially salvageable).

## Non-goals

- The iOS notification-budget overflow (audit item 3) — separate change.
- The midnight-staleness refresh (item 4) and `_sync` re-entrancy guard (item 5)
  — separate changes; both touch UI/coordinator lifecycle, not write paths.
- Defensive parsing inside `computeReminderSchedule` itself. Validating at the
  import boundary fully closes the data path: `reminderTime` can only enter via
  the time picker (always `HH:mm`) or via import (now validated). A redundant
  compute-layer guard is deferred unless a second entry point appears.
- Disabling/`await`-ing the checkbox in the UI. The DAO-level fix makes the
  operation safe regardless of how the UI calls it; a UI-level guard is belt-and-
  suspenders and out of scope.

## Design

### 1. Atomic, idempotent `toggleCompletion`

Wrap the read + write in a single `transaction(() async { … })` so the
check-then-act is serialized, **and** make the insert tolerate a concurrent
winner. Replace the bare insert with `InsertMode.insertOnConflictUpdate` is
wrong here (we want delete-on-present, not upsert); instead keep the
read/branch but run it inside `transaction()`, which on the in-memory and
on-device SQLite serializes the two concurrent toggles. The losing toggle then
re-reads the now-present row and takes the delete branch — so two near-simultaneous
taps net to the *intended* toggled state rather than crashing.

Concretely, the body of `toggleCompletion` moves inside `transaction(() async {
… })` unchanged in logic. Drift serializes transactions on a single connection,
so the second toggle observes the first's write. The method's existing contract
("inserts if absent, deletes if present; idempotent with respect to the displayed
state") is preserved and now actually holds under concurrency.

### 2. Validate `reminderTime` format on import

In `_decodeHabit`, after the existing `reminder is! String` check, reject any
non-`HH:mm` string with a `BackupFormatException`, mirroring how completion dates
use `_isValidIsoDate`. Add a sibling helper:

```dart
bool _isValidHhmm(String s) {
  return RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(s);
}
```

and in `_decodeHabit`:

```dart
final reminder = item['reminderTime'];
if (reminder != null && (reminder is! String || !_isValidHhmm(reminder))) {
  throw BackupFormatException('Habit "$name" has an invalid reminderTime.');
}
```

`null` (no reminder) stays valid. This matches the DB column contract
(`reminderTime // 'HH:mm', null = none`) and the message is unchanged.

### 3. De-duplicate completion dates on import

In `_decodeHabit`, collect completions into a structure that drops exact-duplicate
date strings while preserving first-seen order, so a duplicate is tolerated rather
than turned into a hard SQLite failure. Validation of each date is unchanged
(still `_isValidIsoDate`); only the dedup is added:

```dart
final seen = <String>{};
final completions = <String>[];
for (final c in completionsRaw) {
  if (c is! String || !_isValidIsoDate(c)) {
    throw BackupFormatException('Habit "$name" has an invalid completion date: $c.');
  }
  if (seen.add(c)) completions.add(c);
}
```

A genuinely *invalid* date still throws (we don't silently swallow bad data); only
a redundant valid date is collapsed.

## Testing

Failing-test-first for each, mirroring existing style (in-memory `NativeDatabase`
for the DAO, plain string fixtures for the codec):

1. **DAO concurrency** (`habit_dao_test.dart`): fire two `toggleCompletion` calls
   for the same `(habitId, date)` concurrently (`Future.wait([t1, t2])` without
   awaiting between) and assert it completes without throwing and the net state is
   a single deterministic toggle (present-then-absent or absent-then-present),
   never a `SqliteException`.
2. **Codec reminderTime** (`backup_codec_test.dart`): a backup with
   `reminderTime: "9am"` (and `""`, `"99:99"`) throws `BackupFormatException`; a
   valid `"08:30"` and an absent/`null` reminder both decode cleanly.
3. **Codec dedup** (`backup_codec_test.dart`): a habit whose `completions` lists
   the same valid date twice decodes to a single occurrence and, fed through
   `importReplace`, imports without a unique-constraint failure.

Full suite (`flutter test`) stays green; `flutter analyze` clean.

## Risk

- **Low.** Each fix is localized and additive. The `transaction()` wrap is the
  only behavioral change to an existing path; Drift transactions on a single
  connection are well-trodden and already used by `reorderHabits` and
  `importReplace`, so the pattern matches the codebase.
- The reminderTime validation tightens what import accepts. A previously-importable
  (but already-broken) file with a malformed time now fails fast at import with a
  clear message instead of crashing later — a strictly better failure mode, but
  worth noting it changes import from "accepts then crashes" to "rejects cleanly."

## Architecture promotion

Update [`architecture/backup-io.md`](../../../architecture/backup-io.md) — note
that `reminderTime` is format-validated and completion dates are de-duplicated on
import — and [`architecture/habit-tracking.md`](../../../architecture/habit-tracking.md)
— note `toggleCompletion` is transactional/idempotent under concurrency — in the
implementing PR, alongside the code.

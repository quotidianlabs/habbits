---
status: approved
date: 2026-06-17
slug: completion-pct-first-check
supersedes: null
superseded_by: null
pr: null
outcome: null
---

# Change: Anchor 30-day completion % at first checked day, not creation date

**Lane:** lightweight — two production files (a pure function + its one call
site) plus the function's own test. No new files, single consumer.

## Goal

The 30-day completion % anchors its window at `habit.createdAt`. Two problems
follow from retroactive editing (which lets a user backfill checks on days
*earlier* than `createdAt`):

1. **Checks before the creation date are ignored** — they fall outside the
   window, so they never count toward the metric.
2. **The denominator is the creation span, not the activity span** — a habit
   created long ago but only recently started is diluted by its empty early
   days.

Anchoring the window at the **first checked day** instead of `createdAt` fixes
both. `createdAt` stops factoring into this metric entirely.

## Approach

In `completionPercent`, replace the creation-date anchor with the earliest
checked day:

- Drop the `createdAt` parameter. New signature:
  `int? completionPercent(Set<DateTime> completed, DateTime today)`.
- Empty `completed` → `null` ("—"). This is the only source of `null` now.
- `lastDay` = today if checked, else yesterday (**unchanged**).
- `firstDay` = earliest checked day (replaces `created`).
- `spanDays = daysBetween(firstDay, lastDay) + 1`;
  `windowDays = min(30, spanDays)`; count checks in the trailing `windowDays`.

The rolling-30 cap for established habits is preserved, so `thirtyDayLabel`
stays accurate; only the *anchor* of a sub-30-day window moves.

**Deliberate behavior change (approved):** a habit created N days ago with
**zero** checks currently shows `0%`; it now shows `—`. With no checks there is
no first-checked day, so "no window yet" is the truthful state — and it avoids
shaming an unstarted habit with `0%`.

`createdAt` remains on the `Habit` model for backup/audit and sort order; only
this metric stops reading it. No DB or schema change.

Truth home: this metric is described in
[`architecture/streaks-and-stats.md`](../../../../architecture/streaks-and-stats.md)
— promote the new anchor wording there on merge.

## Files

- `lib/domain/completion_stats.dart` — new signature + first-checked-day anchor;
  refresh the doc comment.
- `lib/ui/habit_list/habit_list_view_model.dart` — drop the
  `row.habit.createdAt` argument at the `completionPercent(...)` call site.
- `test/domain/completion_stats_test.dart` — drop the `created` arg throughout;
  update the two cases whose numbers shift (denominator now follows first-check,
  not creation); add: checks-before-creation counted, and zero-checks → `null`.

### Test-number deltas (first-check denominator)

- *"partial window under 30 days"* — first check 3 days ago, not 4-days-ago
  creation: window 4, 3 done → **75** (was 60).
- *"window caps at 30 days"* — 15 checks, first check 14 days ago: window 15
  (< 30), 15 done → **100** (was 50). Add a separate case where the first check
  is > 30 days back to keep coverage of the 30-day cap.

## Verification

- [ ] Failing test first — add the checks-before-creation case, run
  `flutter test test/domain/completion_stats_test.dart` — fails on old anchor.
- [ ] Apply the change.
- [ ] `flutter test test/domain/completion_stats_test.dart` — green.
- [ ] `just test` — full suite green.
- [ ] `just lint` — clean (`dart format` + `flutter analyze`).

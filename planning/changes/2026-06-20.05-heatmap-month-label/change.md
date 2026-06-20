---
status: shipped
date: 2026-06-20
slug: heatmap-month-label
summary: Place the heatmap month label on the column containing the 1st, not the column's Monday.
supersedes: null
superseded_by: null
pr: null
outcome: |
  Extracted a testable monthLabels() that labels the column containing the 1st.
  Closes audit #8. +1 test (147 total), lint clean.
---

# Change: Fix heatmap month-label column placement

**Lane:** lightweight — one widget file + a test, no new public API.

## Goal

The detail-screen heatmap labels months one column late (up to ~6 days) when a
month starts mid-week. Audit item #8 (Low). Place the label on the column that
actually contains the month's 1st.

## Approach

`HeatmapGrid._monthLabels` decides a column's month from `week.first.date.month`
— the column's **Monday**. A month visually begins in whatever column contains
its 1st, which is the Monday only when the 1st falls on a Monday. When the 1st
falls Tue–Sun the label lands one column right, and if the new month's first
column is the last one (its Monday still in the old month) the label is dropped
entirely.

Fix: extract a testable top-level `monthLabels(weeks, localeName)` that labels the
column **containing a day-1 cell** with that month (the leftmost column falls back
to its first cell's month as a starting reference). Truth home unchanged
(`architecture/streaks-and-stats.md` already describes the heatmap as a read-only
picture).

## Files

- `lib/ui/widgets/heatmap_grid.dart` — replace `_monthLabels` with a top-level
  `monthLabels` that keys off the 1st-of-month cell.
- `test/ui/heatmap_grid_test.dart` — assert the label sits on the column holding
  `2026-07-01` (July 1 is a Wednesday).

## Verification

- [ ] Failing test first — `monthLabels` puts `'Jul'` on the July-1 column.
- [ ] Apply the fix.
- [ ] `flutter test test/ui/heatmap_grid_test.dart` passes.
- [ ] `just test` green; `just lint` clean.

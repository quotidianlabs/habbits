# Streaks and stats

## Purpose

Pure functions that turn a habit's set of completed dates into a current streak,
a completion percentage, and the data structures that drive calendar visualizations
(multi-week heatmap and recent-days strip). The `domain/` layer has no Flutter or
Drift imports; the `ui/widgets/` layer only renders the results.

## Behavior

- The **detail screen** shows the current streak (days), the 30-day completion %,
  a multi-week heatmap, and a recent-days list.
- **Current streak** is computed fresh on every render from the live completion
  set — it is never stored.
- **Completion %** is a rolling window over at most the last 30 days, anchored at
  the **first checked day** (not the creation date) — so retroactively backfilled
  checks, including ones before the habit was created, count, and the denominator
  follows how long the habit has actually been active. When nothing is checked yet
  there is no window and the UI renders "—".
- The **heatmap** (`HeatmapGrid`) is a read-only grid of week-columns
  (Mon→Sun rows). Future cells are blank and non-interactive.
- The **recent-days list** (`RecentDaysList`) renders the last 30 days
  newest-first (the underlying `recentDays` function returns oldest→newest; the
  widget reverses before rendering); tapping any row (or its checkbox) calls
  `onToggle` with that date, allowing retroactive edits. Streak and % recompute
  automatically through the existing reactive stream.
- The **day strip** (`DayStrip`) is a compact read-only one-row bar of the last
  N days (default 14), used on the home card for a glanceable completion picture.
- **"Today"** comes from `currentDayProvider` (`lib/ui/core/current_day.dart`),
  a live value that ticks at local midnight and refreshes on app resume. Every
  rendered view derives from it — the home-list scalars, the card day-strip, and
  the detail heatmap + recent-days — so streak, done-today, completion-%, and the
  calendar grids all stay correct across a day boundary with the app left open
  and no DB write. No view reads the wall clock — the home check-off
  (`toggleToday`) also writes the `currentDayProvider` day, so the completion a
  tap records always lands on the day the strip shows, even in the midnight
  window before the ticker's timer fires.

## Code map

- `lib/domain/models/habit_summary.dart` — `HabitSummary.from(HabitWithDates, today)`:
  the single home for the per-habit scalar composition; normalizes its inputs to
  date-only, then composes `currentStreak`, `completionPercent`, and done-today
  into a `HabitSummary`. Both the home list and the detail screen build summaries
  through this factory; the parameterized calendar builders below stay separate.
- `lib/domain/streak.dart:8` — `currentStreak(completed, today) → int`: pure function;
  the single authoritative streak computation
- `lib/domain/completion_stats.dart:12` — `completionPercent(completed, today) → int?`:
  pure function; window anchored at the first checked day; returns null when
  nothing is checked yet
- `lib/domain/heatmap.dart:23` — `buildHeatmap({completed, today, weeks}) → HeatmapData`:
  pure function; produces the week-column/cell grid consumed by `HeatmapGrid`
- `lib/domain/heatmap.dart:4` — `CellState` enum (`completed`, `notCompleted`, `future`)
  and `HeatmapCell`/`HeatmapData` value types
- `lib/domain/recent_days.dart:13` — `recentDays(completed, today, count) → List<RecentDay>`:
  pure function; returns `count` entries in oldest→newest order ending at `today`;
  consumed by both `DayStrip` and `RecentDaysList` (the latter reverses for display)
- `lib/domain/dates.dart:5` — calendar-date helpers (`dateOnly`, `previousDay`,
  `daysBetween`, `mondayOf`, `formatIsoDate`, `parseIsoDate`); no Flutter or Drift
  imports; all date math goes through this file
- `lib/ui/widgets/heatmap_grid.dart:9` — `HeatmapGrid`: read-only `StatelessWidget`
  that renders a `HeatmapData` as a grid; supports optional month labels
- `lib/ui/widgets/day_strip.dart:7` — `DayStrip`: read-only one-row strip of the last
  N days, calling `recentDays` internally
- `lib/ui/widgets/recent_days_list.dart:10` — `RecentDaysList`: newest-first list of
  the last N days; the only widget in this capability that is interactive (exposes
  `onToggle`)

## Invariants

- **`currentStreak`** (`lib/domain/streak.dart:8`): if today is in the completed
  set the streak anchors at today; if today is absent but yesterday is present the
  streak anchors at yesterday (the streak is still alive until the day actually
  lapses); if neither today nor yesterday is present the function returns 0
  immediately. From the anchor the function counts backward one day at a time,
  incrementing the count for every day found in the set; the first missing day
  stops the walk. A single missed day therefore resets the streak to 0.
- **`completionPercent`** (`lib/domain/completion_stats.dart:12`):
  - Returns null when the completed set is empty (no window yet).
  - `lastDay` = today if today is completed, otherwise yesterday.
  - `firstDay` = the earliest completed day; `spanDays` = `daysBetween(firstDay,
    lastDay) + 1` (the creation date is not consulted).
  - `windowDays` = `min(30, spanDays)`.
  - `windowStart` = `lastDay − (windowDays − 1)` calendar days.
  - Result: completed dates in `[windowStart, lastDay]` ÷ `windowDays` × 100, rounded.
- All date comparisons in the domain layer use `dateOnly`/`previousDay` from
  `lib/domain/dates.dart:5`; time-of-day never leaks into streak or percentage
  calculations, and DST transitions do not shift calendar-day counts.
- `HabitSummary.from` is the only construction path for a `HabitSummary`. It
  normalizes `today` and every completion date to date-only, so done-today and
  the stored `dates` set never depend on callers pre-normalizing.
- `buildHeatmap` always produces exactly `weeks` week-columns (default 6), each
  containing exactly 7 cells in Mon→Sun order. The last column ends at the week
  containing `today`. Cells after `today` carry `CellState.future` and are never
  marked completed.
- `recentDays` always returns exactly `count` entries in oldest→newest order,
  ending at `today`. No future dates are included.

## Known edges

None currently tracked.

## History

Defined by: [2026-06-13.01-foundation](../planning/changes/archive/2026-06-13.01-foundation/design.md), [2026-06-13.02-heatmap-retroactive-editing](../planning/changes/archive/2026-06-13.02-heatmap-retroactive-editing/design.md), [2026-06-17.01-completion-pct-first-check](../planning/changes/archive/2026-06-17.01-completion-pct-first-check/change.md). Scalar composition moved into `HabitSummary.from` and all rendered views switched to `currentDayProvider` in [2026-06-24.01-habit-summary-factory](../planning/changes/2026-06-24.01-habit-summary-factory/design.md). The home check-off (`toggleToday`) switched from the wall clock to `currentDayProvider` in [2026-06-24.02-toggle-today-anchor](../planning/changes/2026-06-24.02-toggle-today-anchor/change.md).

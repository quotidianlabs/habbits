---
status: accepted
summary: HabitSummary.from owns only the scalar projection; the calendar builders (buildHeatmap, recentDays) stay pure view-parameterized functions, not absorbed into the projection.
supersedes: null
superseded_by: null
---

# Keep the habit projection scalar-only

**Decision:** `HabitSummary.from(HabitWithDates, today)` composes only the
per-habit *scalars* (streak, done-today, completion %, and the normalized date
set). The calendar builders `buildHeatmap(weeks:)` and `recentDays(count:)` stay
pure functions called by the widgets — they are **not** folded into the
projection.

## Context

The 2026-06-24 architecture review (candidate A, the `projectHabit` proposal)
recommended a single projection module owning the whole "completions + today →
display shape" derivation — streak, completion %, done-today **and** the heatmap
and recent-days grids — so both screens cross one interface.

[habit-summary-factory](../changes/2026-06-24.01-habit-summary-factory/design.md)
(#21) shipped the scalar half as `HabitSummary.from` and deliberately stopped
there, leaving the calendar builders where they were. This records why, so a
later explorer doesn't "finish the job" by absorbing them.

## Decision & rationale

The scalars and the calendar grids have different shapes of input:

- **Scalars take no view parameters.** For a given `(habit, today)` there is one
  correct streak, one completion %, one done-today. That single-valued-ness is
  exactly what makes one home worthwhile — every caller wants the same answer,
  and the normalization invariant lives at the interface.
- **The calendar builders are parameterized by view-specific layout.**
  `buildHeatmap` takes `weeks: 6` (detail); `recentDays` takes `count: 14` (the
  home day-strip) and `count: 30` (the detail recent-days list). Those counts are
  properties of the *view*, not the habit.

Folding the builders into a per-habit projection would force one of:
(a) a single fixed layout for all callers (wrong — the strip and the list differ),
or (b) threading the layout params through the projection, which just relocates
the call without adding cohesion. Either way there is no shared answer to
concentrate. Kept pure, the builders also stay independently testable and
reusable by any widget without constructing a `HabitSummary`.

So the seam is drawn at single-valued-per-habit: scalars in, layout-parameterized
grids out.

## Revisit trigger

Reopen if **either**: a third+ caller needs the heatmap/recent-days with the
*same* layout params (a shared default worth a home appears), **or** the
scalar/calendar split causes a real normalization bug (e.g. `today` normalized
in two places drifting) — at which point a unified projection that accepts
layout params may earn its keep.

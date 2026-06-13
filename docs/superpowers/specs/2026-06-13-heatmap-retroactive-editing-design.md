---
title: "Habbits — heatmap + retroactive editing (Plan 2) design"
date: 2026-06-13
status: approved
type: design
references:
  - docs/superpowers/specs/2026-06-13-habbits-mobile-local-first-design.md
---

# Habbits — heatmap + retroactive editing (Plan 2)

Second feature slice on top of the merged foundation + core loop. Implements the
spec §6 MVP items **GitHub-style heatmap**, **retroactive editing**, and
**30-day completion %**. No schema change: the data layer already supports
toggling any date (`HabitDao.toggleCompletion(habitId, date)` accepts any date)
and already streams each habit's full completion set (`watchHabitsWithDates()`).
This slice adds two pure-Dart domain functions, a reusable heatmap widget, a new
detail screen, and a restructured home card.

## 1. Screens & interactions

### Home — list of habit cards
The home screen becomes a list of **habit cards** (replacing the current
checkbox+streak row). Each card shows:
- habit name and current streak,
- a **read-only mini-heatmap** (glanceable; not editable here),
- the **30-day completion %**,
- a **dedicated check-off control** that toggles **today only** (the daily loop;
  a comfortable tap target, independent of the small heatmap cells).

Tapping the **card body** (anywhere except the check control) opens the detail
screen. Rename and delete are **removed from the home card** — they live on detail.

### Habit detail screen (new)
- **Full scrollable heatmap** over the habit's whole history.
- Current streak and 30-day % shown as text.
- **Retroactive editing:** tapping any in-range day toggles that day's completion.
- **Rename** and **hard-delete** (delete keeps the foundation's permanent-delete
  confirmation, then pops back to home).

## 2. Heatmap model & rules

A GitHub-style grid: **columns = weeks, rows = 7 weekdays** (Mon→Sun row order,
chosen once and fixed). A **pure-Dart** function in `lib/domain/heatmap.dart`
turns a habit's completion dates + `createdAt` + `today` into grid cells. Each
cell has a date and one state:

- **completed** — in range and has a completion → rendered in the habit's color.
- **notCompleted** — in range, no completion → faint/empty.
- **future** — date > today → blank (rendered only for grid alignment; never a
  "missed" cell, never tappable).
- **beforeCreation** — date < `createdAt` → blank (leading alignment cells in the
  first week; never tappable).

"In range" means `createdAt … today` inclusive (date-only).

- **Mini-heatmap (home card):** the most recent whole weeks that fit the card
  width (target ~16–18 weeks), no scrolling, **read-only**.
- **Full heatmap (detail):** from the week containing `createdAt` through the week
  containing `today`, **scrollable**, with month labels along the week axis,
  **tappable**.

### Retroactive editing rules
- Tappable range = `createdAt … today` inclusive. Tapping a cell calls
  `toggleCompletion(habitId, cellDate)` (insert if absent, delete if present).
- **No future check-offs:** `future` cells are non-interactive.
- **No pre-creation check-offs:** `beforeCreation` cells are non-interactive.
- Streak and 30-day % are **derived, not stored**, so any toggle (past or today)
  recomputes them automatically through the existing reactive stream.

## 3. 30-day completion %

Pure-Dart function in `lib/domain/completion_stats.dart`, per foundation spec §3:

> completed days ÷ min(30, days since creation), excluding today when it is not
> yet checked.

Implementable rule (date-only throughout):
- Let `lastDay` = today if today is checked, else yesterday (today is excluded
  when unchecked).
- Let `windowDays` = min(30, number of days from `createdAt` through `lastDay`,
  inclusive).
- Let `completed` = count of completions in the window `[lastDay - windowDays + 1
  … lastDay]`.
- Result = round(`completed` / `windowDays` × 100), as an integer percent.
- **Edge — empty window:** if `windowDays ≤ 0` (e.g. habit created today and not
  yet checked, so `lastDay` precedes `createdAt`), there is no eligible window →
  the function returns **null**, which the UI renders as **"—"**. As soon as one
  eligible day exists, a real percent shows.

Covered by table-driven tests (created-today, partial <30-day window, today
checked vs unchecked, cap at exactly 30, a gap reducing the percent).

## 4. Architecture

No schema change. New and changed files:

```
lib/domain/
  completion_stats.dart   # NEW (pure): completionPercent(dates, createdAt, today) -> int?
  heatmap.dart            # NEW (pure): buildHeatmap(dates, createdAt, today, weeks?) -> grid
lib/state/
  habit_providers.dart    # HabitSummary gains `completionPercent` (int?) and `dates`
                          #   (Set<DateTime>) so the card can render its mini-heatmap.
                          # NEW habitDetailProvider(id): derives a single habit's
                          #   dates/streak/%/heatmap from the SAME watchHabitsWithDates
                          #   stream, so edits made on detail update the home card too.
lib/ui/
  widgets/heatmap_grid.dart           # NEW: one reusable grid widget, parameterized by
                                      #   (cells, interactive?, onToggleDate?). Mini passes
                                      #   interactive:false; full passes interactive:true.
  habit_list/habit_list_screen.dart   # card = name + streak + mini-heatmap + % + check button;
                                      #   card body navigates to detail.
  habit_detail/habit_detail_screen.dart  # NEW: full heatmap + stats + retroactive edit +
                                         #   rename + delete-with-confirm.
```

**Decomposition notes.** The two domain functions are pure and independently
unit-tested (no Flutter/Drift). The heatmap *rendering* is a single widget reused
at two sizes/interactivities, so the grid logic lives in one place. The detail
provider derives from the existing reactive stream rather than opening a second DB
query, keeping a single source of truth and automatic cross-screen updates.

**Rendering.** `heatmap_grid.dart` builds the grid with a `GridView`/`Wrap` of
small fixed-size cells (simple and adequate at this scale — a few hundred cells).
`CustomPainter` is a later optimization only if profiling on-device demands it;
not in this slice.

## 5. Testing

- **Domain (TDD, table-driven, pure Dart):**
  - `completion_stats`: created-today → null/"—"; partial window (<30 days);
    today checked vs unchecked changes `lastDay`; cap at exactly 30 days; a missed
    day lowers the percent; round-half behavior is asserted explicitly.
  - `heatmap`: weekday/row alignment; range starts at the `createdAt` week and ends
    at the `today` week; `future` and `beforeCreation` cells are blank/non-tappable;
    completed vs notCompleted classification.
- **Widget:**
  - Home card renders the mini-heatmap, the 30-day % (and "—" for a brand-new
    habit), and the check button; the check button toggles **today** and the streak
    updates; tapping the card body navigates to detail.
  - Detail screen renders the full grid; **tapping a past in-range cell toggles it**
    and the streak + % update; a `future` cell tap is a no-op; rename and
    delete-with-confirm work (delete returns to home).
- **Regression:** the home card replaces the old checkbox row, so the existing
  `habit_list_screen_test.dart` cases are updated to the new card structure; the
  rest of the suite stays green.
- **Out of scope for the integration test:** the existing critical-flow
  integration test stays as-is; an optional extra retroactive-edit on-device check
  may be added in a later slice, not here.

## 6. Out of scope (unchanged from the foundation backlog)

Reminders (Plan 3), CSV/JSON export+import (Plan 4), home-screen widget (Plan 5),
quantity-based habits, flexible cadence, best-streak metric, intensity-graded
heatmap cells (boolean habits render binary cells only). No cloud sync.

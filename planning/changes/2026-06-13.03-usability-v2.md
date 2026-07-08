---
summary: Usability pass across home, detail, and dialogs.
---


# Habbits — home/detail usability v2

Dogfooding surfaced two usability problems, addressed here:

1. **Home cards are too tall.** The 7-row (Mon→Sun) mini-heatmap dominates each
   card vertically, so a list of habits scrolls a lot and the per-habit status is
   hard to scan.
2. **The detail heatmap is hard to edit by day.** Plain colored squares carry no
   date, so backfilling "the day I missed" is guesswork.

No schema or state change: `HabitDao.toggleCompletion(habitId, date)` and
`HabitSummary.dates` already support everything here.

## 1. Home card (compact)

Each card becomes **two short lines** instead of three sections:

- **Line 1:** today's check-off `Checkbox` + habit name + `Streak: N` + 30-day %
  (e.g. `☑  Medicine      Streak: 5    80%`; the % renders `—` when there is no
  window yet).
- **Line 2:** a **single-row "last 14 days" strip** (`DayStrip`) — one cell tall,
  oldest→newest, completed cells in the habit color, the rest faint. A glanceable
  recent-activity sliver that replaces the tall 7-row grid.

Tapping the card body still opens the detail screen; the `Checkbox` is its own tap
target and toggles **today** only.

The `30-day:` label prefix is dropped (just `80%`). The 7-row `HeatmapGrid` is
removed from the home card.

**Streak text:** stays as the literal text `Streak: N` (not a 🔥 icon). The merged
on-device integration test and the home widget tests assert that exact string;
keeping it avoids breaking them and an emulator re-run. Switching to a flame icon
is a deliberate, separate follow-up.

## 2. Detail screen

Editing moves from tapping heatmap squares to an explicit, labeled list:

- **Stats** — `Streak: N` and `30-day: X%` (unchanged).
- **Read-only heatmap** — the existing 6-week `HeatmapGrid` with month labels, now
  **non-interactive**: it is the pattern "picture," not the editor.
- **Recent-days list** (`RecentDaysList`) — the last **30 days**, **newest first**.
  Each row shows the weekday + date and a toggle, e.g. `Today · Sat Jun 13  ☑`,
  `Fri Jun 12  ☐`. Tapping a row (or its checkbox) toggles that day's completion via
  `toggleCompletion(habitId, date)`. Streak, %, the strip, and the heatmap all
  recompute reactively. Future days never appear (the list ends at today).

Rename/delete remain in the detail app-bar (unchanged from the previous slice).

Because the heatmap is now read-only everywhere (the home card uses `DayStrip`),
**`HeatmapGrid`'s interactive/`onToggle` path is pruned** (YAGNI) — the widget
becomes a pure renderer.

## 3. Architecture

```
lib/domain/
  recent_days.dart       # NEW (pure): RecentDay{date, completed};
                         #   recentDays(completed, today, count) -> List<RecentDay>
                         #   (oldest→newest, today inclusive, no future days)
  calendar_labels.dart   # NEW (pure): monthAbbr3(int 1..12), weekdayAbbr3(int 1..7)
                         #   (DRY — the month-label strings currently inlined in
                         #    heatmap_grid.dart move here; reused by the list)
lib/ui/widgets/
  day_strip.dart         # NEW: home one-row recent strip (read-only)
  recent_days_list.dart  # NEW: detail editing list (newest-first, onToggle(date))
  heatmap_grid.dart      # CHANGE: drop interactive/onToggle/_editable + the cell
                         #   GestureDetector; use calendar_labels for month labels
lib/ui/habit_list/habit_list_screen.dart    # compact 2-line card using DayStrip
lib/ui/habit_detail/habit_detail_screen.dart # read-only heatmap + RecentDaysList
```

**Decomposition:** `recentDays` is pure and shared by both the strip and the list,
so the "which days, in order, completed?" logic lives in one tested place. The two
widgets are thin renderers over it. `DayStrip` is read-only; `RecentDaysList` owns
the toggle interaction. The detail screen composes (stats + read-only heatmap +
list); the home card composes (info line + strip).

## 4. Product rules / windows

- **Home strip:** last **14 days**, oldest→newest, read-only.
- **Detail list:** last **30 days**, newest→oldest (today first), editable.
- **Detail heatmap:** unchanged 6-week read-only window with month labels.
- A day is "completed" iff its date (date-only) is in the habit's completion set.
- No future days in the strip or the list.

(The strip/list/heatmap windows differ by design — strip is a tiny glance, the list
is the practical one-month backfill range, the heatmap is the broader picture. The
list is the single editable surface, so there is no ambiguity about where to edit.)

## 5. Testing

- **Domain (pure, TDD):** `recentDays` — returns `count` days ending today, ordered
  oldest→newest, `completed` flags correct, today included, no future days, DST-safe
  date stepping.
- **Widgets:**
  - `DayStrip` — renders `count` cells; completed vs not reflected; read-only.
  - `RecentDaysList` — renders the last N days newest-first with today labeled;
    tapping a row toggles that day (assert against the DB through the real DAO).
  - `HeatmapGrid` — after pruning interactivity: renders cells + month labels; the
    former interactive/gesture tests are removed (no longer applicable).
- **Updated screen tests:**
  - Detail: retroactive edit now happens via a `RecentDaysList` row tap (not a
    heatmap cell); the heatmap is read-only. Delete/rename/render tests stay.
  - Home: card shows `Streak: N` text + a `Checkbox` + the `DayStrip` (not the
    7-row grid); add/check-off/two-habit/navigation cases preserved.
- **Integration test** (`integration_test/critical_flow_test.dart`): unchanged and
  still valid — it only touches the home `Checkbox`, `Streak: 1`, and `Medicine`
  text, all preserved. Not run as part of this slice (needs an emulator).

## 6. Out of scope

Flame/icon streak indicator (deliberate follow-up; would require updating the
integration + widget tests and an emulator re-run), reminders (Plan 3), export
(Plan 4), home-screen widget (Plan 5), the 30-day-% "days since creation" basis
(a separate question if backfilling pre-creation days makes the % look off), any
schema/sync change.

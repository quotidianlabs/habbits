# Habit tracking

## Purpose

The create/track/edit loop for habits and their daily completion records.

## Behavior

- Add a habit by supplying a name and a color (chosen from a curated swatch palette, defaulting to teal); the habit appears at the bottom of the home list with a unique sort position.
- Check a habit off for today from the home list, or toggle any date (including past dates) from the detail screen's heatmap.
- Edit a habit's name and color, delete it, or change its reminder time from the detail screen; deleting a habit hard-deletes it and all its completions via `ON DELETE CASCADE`.
- Drag the handle on any home-list card to reorder habits; the new order is persisted immediately and the list re-renders from the stream.
- State flows: view → view model → `HabitRepository` → `HabitDao` → Drift (SQLite). The reactive `watchHabits()` stream propagates every change back to the UI automatically.

## Code map

- `lib/data/repositories/habit_repository.dart:12` — public data API; the only habit-data seam that view models depend on
- `lib/data/services/database/habit_dao.dart:11` — Drift `DatabaseAccessor`; executes all SQL (CRUD, toggle, reorder, import)
- `lib/data/services/database/database.dart:8` — Drift schema (`Habits`, `Completions` tables) and `AppDatabase` wiring
- `lib/domain/reorder.dart:8` — pure function `reorderedIds(ids, oldIndex, newIndex)`: computes the updated id list for a drag move without mutating the input
- `lib/domain/models/habit_summary.dart:8` — `HabitSummary`: per-habit view value (streak, doneToday, completionPercent, dates) used by both view models; built only via the `HabitSummary.from(HabitWithDates, today)` factory (see [`streaks-and-stats.md`](streaks-and-stats.md))
- `lib/domain/models/habit_with_dates.dart:4` — `HabitWithDates`: DAO/repository transfer object pairing a `Habit` row with its completion date set
- `lib/ui/habit_list/habit_list_view_model.dart:14` — home-screen view model: streams `List<HabitSummary>`, exposes `toggleToday`, `reorder`, `createHabit`
- `lib/ui/habit_detail/habit_detail_view_model.dart:12` — detail-screen view model (one instance per `habitId`): state derived from the list view model, exposes `toggle`, `editHabit` (name + color), `delete`, `setReminder`
- `lib/ui/widgets/habit_dialogs.dart:8` — the create/edit dialog (`showHabitNameDialog`, a `StatefulWidget` that collects a name and a color from a `kHabitPalette` swatch picker and returns a `HabitFormResult`) and the delete confirmation (`confirmDeleteHabit`); `setColor` on `HabitDao`/`HabitRepository` applies the color edit. Swatch palette lives in `lib/ui/core/habit_colors.dart` (see [`theming.md`](theming.md))

## Invariants

- Every habit carries an explicit integer `sortOrder`. `HabitDao.reorderHabits` assigns each habit its index in the provided list within a single transaction, making `sortOrder` values dense (`0..n-1`) after any reorder. New habits are assigned `max(existing sortOrder) + 1` (0 for an empty list), so they always land at the end with a unique position even after deletions.
- A completion is keyed by `(habitId, localDate)` with a `UNIQUE` constraint enforced at the database level. A given day is either done or not — no partial or duplicate marks. `toggleCompletion` inserts if absent and deletes if present, running its read and write in a single transaction so two near-simultaneous toggles (a rapid double-tap) serialize rather than both inserting and colliding on the unique key.
- Deleting a habit removes all its completions immediately via `ON DELETE CASCADE`; there is no soft-delete or tombstone.
- Foreign keys are enabled at open time (`PRAGMA foreign_keys = ON`).

## Known edges

- None currently. The prior undisposed-`TextEditingController` edge in
  `showHabitNameDialog` was resolved when the dialog became a `StatefulWidget`
  in [2026-06-15.07-dark-theme-and-color-picker](../planning/changes/archive/2026-06-15.07-dark-theme-and-color-picker/design.md).

## History

Defined by: [2026-06-13.01-foundation](../planning/changes/archive/2026-06-13.01-foundation/design.md), [2026-06-14.03-reorder-habits](../planning/changes/archive/2026-06-14.03-reorder-habits/design.md), [2026-06-15.01-architecture-refactor](../planning/changes/archive/2026-06-15.01-architecture-refactor/design.md). User-chosen habit color on create/edit (swatch picker + `setColor`/`editHabit`) added in [2026-06-15.07-dark-theme-and-color-picker](../planning/changes/archive/2026-06-15.07-dark-theme-and-color-picker/design.md).

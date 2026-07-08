---
summary: Layered MVVM with Riverpod: repositories, per-feature view models, feature-first tree.
---

# Layered architecture refactor (Riverpod MVVM) — design

**Date:** 2026-06-15
**Status:** Approved (pending spec review)

## Goal

Restructure the Habbits codebase to match Flutter's official app-architecture
guidance (layered architecture + MVVM), expressed with the app's existing
Riverpod idioms. This is a **behavior-preserving structural refactor**: zero
user-visible change, all existing tests stay green throughout.

Non-goals: changing any feature behavior; replacing Riverpod with
ChangeNotifier/manual DI; introducing separate domain models with mappers (Drift
entities remain the habit model); adding new data sources (e.g. cloud sync).

## Reference

Flutter's official guidance (fetched via the docs): **MVVM** — views + view
models form the UI layer; repositories + services form the data layer; an
optional domain layer holds models and pure logic. Each layer communicates only
with adjacent layers; the UI layer never touches the data layer directly. Data
objects are organized *by type*; UI objects *by feature*.

We adapt this to Riverpod: a "view model" is a `@riverpod` Notifier; dependency
injection is provider-based (`ref.watch`) rather than manual constructor wiring.

## Architecture

Three layers, strict downward dependencies (UI → domain → data):

- **UI layer** (`lib/ui/`): views (screen `ConsumerWidget`s) + per-feature view
  models (`@riverpod` Notifiers). A view only watches its view-model provider
  and calls the view model's command methods. No widget references a repository,
  DAO, or service directly.
- **Domain layer** (`lib/domain/`): pure-Dart functions (use-cases) and value
  models. No Flutter/Drift imports in the pure functions.
- **Data layer** (`lib/data/`): repositories (the seam the view models depend
  on) over services/data sources (Drift DB+DAO, `NotificationService`,
  `SharedPreferences`).

Riverpod supplies the DI the official guide does by hand in `main()`.

## Target folder structure

```
lib/
  main.dart
  ui/
    core/
      locale_controller.dart        (moved from state/)
      reminder_coordinator.dart     (moved from state/)
      theme.dart                    (extracted from main.dart)
    habit_list/
      habit_list_screen.dart
      habit_list_view_model.dart    (NEW)
      widgets/habit_card.dart       (extracted from the screen's _HabitCard)
    habit_detail/
      habit_detail_screen.dart
      habit_detail_view_model.dart  (NEW)
    settings/
      settings_screen.dart
      settings_view_model.dart      (NEW)
    widgets/                        (shared presentational widgets)
      day_strip.dart
      heatmap_grid.dart
      recent_days_list.dart
      habit_dialogs.dart
  domain/
    models/
      habit_summary.dart            (moved from state/habit_providers.dart)
      habit_with_dates.dart         (moved from data/habit_dao.dart)
      backup_data.dart              (BackupData/BackupHabit from domain/backup.dart)
    streak.dart
    completion_stats.dart
    heatmap.dart
    recent_days.dart
    reorder.dart
    reminder_schedule.dart
    dates.dart
    backup_codec.dart               (encode/decode from domain/backup.dart)
  data/
    services/
      database/
        database.dart
        habit_dao.dart
      notification_service.dart     (moved from services/)
    repositories/
      habit_repository.dart         (NEW)
      settings_repository.dart      (NEW)
      backup_repository.dart        (from services/backup_service.dart)
  l10n/                             (unchanged)
test/                              (re-mirrored to the new lib/ layout)
```

`lib/state/` and `lib/services/` are removed; their contents redistribute as
shown. `test/` mirrors `lib/` exactly (e.g.
`test/ui/habit_list/habit_list_view_model_test.dart`,
`test/data/repositories/habit_repository_test.dart`).

## Data layer details

### HabitRepository (`lib/data/repositories/habit_repository.dart`)
Plain class exposed via `habitRepositoryProvider` (`@riverpod`). Holds a
`HabitDao`. Single dependency for all habit data in the view models. Surface
(today's DAO operations, in domain terms):
- `Stream<List<HabitWithDates>> watchHabits()`
- `Future<List<HabitWithDates>> getHabits()`
- `Future<int> createHabit({required String name, required int color})`
- `Future<void> renameHabit(int id, String name)`
- `Future<void> deleteHabit(int id)`
- `Future<void> toggleCompletion(int habitId, DateTime date)`
- `Future<void> reorderHabits(List<int> orderedIds)`
- `Future<void> setReminderTime(int id, String? hhmm)`
- `Future<void> importReplace(List<BackupHabit> habits)`

`HabitDao` remains the Drift data-access detail (still unit-tested directly).
`HabitWithDates` moves to `domain/models/`; the DAO/repository import it from
there.

### SettingsRepository (`lib/data/repositories/settings_repository.dart`)
Wraps `SharedPreferences` (`settingsRepositoryProvider`, with
`sharedPreferencesProvider` overridden in `main` as today). Surface:
- `String? readLocaleToken()` / `Future<void> writeLocaleToken(String token)`

`LocaleController` depends on this instead of touching prefs directly. Provides a
home for future preferences.

### BackupRepository (`lib/data/repositories/backup_repository.dart`)
From `services/backup_service.dart`. Orchestrates `HabitRepository` +
`path_provider`/`share_plus`/`file_picker`:
- `Future<void> exportAndShare()`
- `Future<BackupData?> pickAndDecode()` (throws `BackupFormatException` on bad
  files, as today)

Pure encode/decode stays in `domain/backup_codec.dart`.

## UI layer details (per-feature view models)

All are `@riverpod` Notifiers; views watch them and call their commands. No
behavior changes — errors are surfaced so views show the same SnackBars/dialogs.

### HabitListViewModel (`lib/ui/habit_list/habit_list_view_model.dart`)
- `build()` → `Stream<List<HabitSummary>>` — the home list. The summary mapping
  currently in `habitSummariesProvider` (streak/doneToday/percent/dates) moves
  here, sourced from `HabitRepository.watchHabits()`.
- Commands: `toggleToday(int id)`, `reorder(List<int> ids)`,
  `createHabit(String name)`.
- The screen drops all direct `ref.read(habitDaoProvider)…` calls.

### HabitDetailViewModel (`lib/ui/habit_detail/habit_detail_view_model.dart`)
- Family on `habitId`. `build()` → `HabitSummary?` (derived from the list, as
  `habitDetailProvider` does today).
- Commands: `toggle(DateTime date)`, `rename(String name)`, `delete()`,
  `setReminder(String? hhmm)`.

### SettingsViewModel (`lib/ui/settings/settings_view_model.dart`)
- Commands: `export()`, `import()` (returns a decoded `BackupData?` or signals
  the error kind), `confirmImport(BackupData data)` — delegating to
  `BackupRepository`. The view keeps its existing snackbars/dialog; the language
  picker keeps using `LocaleController`.

### App-level (`lib/ui/core/`)
- `LocaleController` — unchanged logic, now depends on `SettingsRepository`;
  still drives `MaterialApp.locale`.
- `ReminderCoordinator` — unchanged glue widget; now depends on
  `HabitRepository` (watch) + `NotificationService` + `LocaleController`.
- `theme.dart` — the `ThemeData(colorSchemeSeed: Colors.teal, useMaterial3:
  true)` extracted from `main.dart` as a named getter.

## Domain layer details

- Pure functions move unchanged under `domain/`: `streak`, `completion_stats`,
  `heatmap`, `recent_days`, `reorder`, `reminder_schedule`, `dates`.
- `domain/backup.dart` splits: encode/decode → `domain/backup_codec.dart`;
  `BackupData`/`BackupHabit` → `domain/models/backup_data.dart`.
- `HabitSummary` (from `state/habit_providers.dart`) and `HabitWithDates` (from
  `data/habit_dao.dart`) move to `domain/models/`. Drift's generated `Habit`
  entity stays the habit model — no mapper layer (design decision).

## Provider wiring

Data-layer providers live next to their classes via `@riverpod`:
`appDatabaseProvider`, `habitDaoProvider`, `habitRepositoryProvider`,
`settingsRepositoryProvider`, `backupRepositoryProvider`,
`notificationServiceProvider`, `sharedPreferencesProvider`. `main.dart` keeps the
two overrides it has today (`notificationServiceProvider`,
`sharedPreferencesProvider`). The monolithic `state/habit_providers.dart` is
dissolved into these provider definitions + the per-feature view models.

## Migration sequence (each step compiles + all tests green)

1. **Models first**: extract `HabitSummary`, `HabitWithDates`, `BackupData`/
   `BackupHabit` into `domain/models/`; split `backup.dart` →
   `backup_codec.dart`. Fix imports. (No logic change.)
2. **Repositories**: introduce `HabitRepository`, `SettingsRepository`,
   `BackupRepository` with provider definitions; point existing providers /
   `LocaleController` / backup callers at them. Add repository unit tests.
3. **View models**: add `HabitListViewModel`, `HabitDetailViewModel`,
   `SettingsViewModel`; move data calls out of the screens into commands; views
   now watch the view models. Add view-model tests. Update widget tests.
4. **Physical reorg**: move files into the final `lib/ui|domain|data` tree
   (including extracting `HabitCard` and `theme.dart`); re-mirror `test/`; fix
   all imports; delete the now-empty `state/` and `services/` directories.
5. **Verify**: `flutter analyze` clean; full suite green; quick simulator smoke
   test to confirm no runtime regression.

## Testing

- All existing tests are preserved (moved/import-fixed), staying green at every
  step.
- New tests: `HabitRepository` (CRUD + watch over an in-memory Drift DB),
  `SettingsRepository` (locale token round-trip with mock prefs), and each view
  model (state + one or two commands, using an overridden repository or in-memory
  DB).
- `test/` mirrors `lib/` so the structure is self-documenting.

## Risks / notes

- **Large, low-risk diff**: touches nearly every file, mostly imports and moves.
  Mitigated by sequencing so the suite stays green at each step and by the
  no-behavior-change constraint.
- The repository layer is a thin pass-through today (single local source); it is
  intentionally introduced as the architectural seam the guide emphasizes and to
  isolate view models from Drift for testing.
- `HabitDao` is retained (not merged into the repository) so Drift specifics stay
  in the data source and the repository stays a plain, mockable class.

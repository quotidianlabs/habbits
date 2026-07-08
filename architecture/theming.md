# Theming

## Purpose

Define the app's light and dark `ThemeData` (Material 3, brand seed color),
apply them app-wide via `MaterialApp`, and let the user pick a theme mode that
persists across launches.

## Behavior

- Two `ThemeData` instances — light and dark — are built from the same teal M3
  seed and applied to `MaterialApp.theme` and `darkTheme` (`lib/main.dart`).
  `themeMode` follows the user's `AppThemeMode` (system / light / dark) and
  defaults to `system`, so the app follows device brightness until the user
  chooses otherwise.
- The chosen mode is persisted to shared_preferences (a `theme` token) via
  `SettingsRepository` and exposed through `ThemeController`, mirroring the
  locale store (see [`i18n.md`](i18n.md)). A selector tile in Settings switches
  it.
- All widget colors and typography are derived from `Theme.of(context)`;
  widgets do not hard-code hex values for chrome elements.
- Per-habit activity colors in `HeatmapGrid` and `DayStrip` are stored as raw
  `Color` ints in the database and passed directly. Completed cells render at
  full habit color; inactive cells render via `inactiveCellColor()` — the habit
  color composited over the current `ColorScheme.surface` (alpha 0.15 light /
  0.30 dark) — yielding an opaque tint that stays visible on either brightness.
  The color is chosen from a curated palette (`kHabitPalette`), every entry of
  which reads on both surfaces. The check mark drawn on the selected swatch in
  the picker uses fixed white-on-swatch (not a `ColorScheme` token), since it
  sits on the swatch fill rather than a theme surface.

## Code map

- `lib/ui/core/theme.dart` — `habbitsLightTheme()` / `habbitsDarkTheme()`:
  the two `ThemeData` factories; `colorSchemeSeed: Colors.teal` (Material teal,
  `#009688`), `useMaterial3: true`, differing only in `brightness`
- `lib/main.dart` — `MaterialApp.theme` / `darkTheme` / `themeMode`;
  `themeMode` is driven by `ref.watch(themeControllerProvider).themeMode`
- `lib/ui/core/theme_controller.dart` — `AppThemeMode` enum (system/light/dark,
  each carrying a `storage` token + a Flutter `ThemeMode`) with a
  `fromStorage` fallback to `system`; `ThemeController` (`@Riverpod(keepAlive:
  true)`) reads/writes the theme token via `SettingsRepository`. Structurally
  mirrors `lib/ui/core/locale_controller.dart`.
- `lib/ui/core/habit_colors.dart` — `kDefaultHabitColor` (teal), `kHabitPalette`
  (the curated swatch list), and `inactiveCellColor(habitColor, scheme)`
- `lib/ui/settings/settings_screen.dart` — the theme selector tile
  (`theme-tile`) + `_pickTheme` / `_themeName`, mirroring the language picker
- `lib/data/repositories/settings_repository.dart` — persists the locale token
  and the theme token (`_themeKey = 'theme'`)
- `lib/ui/widgets/heatmap_grid.dart` — `_cellColor`: completed → `color`;
  not-completed → `inactiveCellColor(color, scheme)`; future → transparent
- `lib/ui/widgets/day_strip.dart` — same inactive-cell treatment
- `lib/ui/habit_list/widgets/habit_card.dart` — chrome (text, drag handle) from
  `Theme.of(context)`

## Invariants

- All chrome colors (text, icons, surfaces) come from `Theme.of(context)` —
  no hex literals for chrome in widget files.
- The brand/seed color is `Colors.teal` (`#009688`), defined in one place
  (`theme.dart`) and also used as the app-icon background in
  `assets/icon/icon.svg`.
- `MaterialApp` provides both `theme` and `darkTheme`; `themeMode` is driven by
  `ThemeController` and defaults to `ThemeMode.system`.
- The theme mode is persisted via the `SettingsRepository` theme token,
  alongside the locale token; an unknown/missing token falls back to `system`.
- Inactive activity cells are opaque (the habit color composited over
  `ColorScheme.surface`), so they render legibly on any brightness.

## Known edges

- None currently. The prior "no dark theme" and "activity cells not
  dark-surface adaptive" edges were resolved in
  [2026-06-15.07-dark-theme-and-color-picker](../planning/changes/2026-06-15.07-dark-theme-and-color-picker.md).

## History

Seed color and the single `habbitsTheme()` established by the foundation slice;
the activity-grid app icon adopted the same teal in:
[2026-06-13.03-usability-v2](../planning/changes/2026-06-13.03-usability-v2.md),
[2026-06-15.02-app-icon-branding](../planning/changes/2026-06-15.02-app-icon-branding.md).
Light/dark themes, the persisted theme-mode selector, and dark-adaptive activity
cells added in
[2026-06-15.07-dark-theme-and-color-picker](../planning/changes/2026-06-15.07-dark-theme-and-color-picker.md).

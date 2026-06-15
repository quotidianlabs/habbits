# Theming

## Purpose

Define the app's `ThemeData` (Material 3, brand seed color) and apply it
app-wide via `MaterialApp`.

## Behavior

- A single `ThemeData` (teal M3 seed) is built once and applied to
  `MaterialApp.theme` only (`lib/main.dart:38`). No `darkTheme:` and no
  `themeMode:` are set; although `themeMode` defaults to `ThemeMode.system`,
  the light palette is always rendered regardless of device brightness — the
  app has no dark mode.
- All widget colors and typography are derived from `Theme.of(context)`;
  widgets do not hard-code hex values for chrome elements.
- Exception: per-habit activity colors in `HeatmapGrid` and `DayStrip` are
  stored as raw `Color` ints in the database and passed directly to the
  widgets — they are not derived from the `ColorScheme`. Inactive cells render
  at 15 % opacity (`color.withValues(alpha: 0.15)`), rendering as a low-opacity
  tint on the light background; they do not adapt to a dark surface.

## Code map

- `lib/ui/core/theme.dart:3` — `habbitsTheme()`: the sole `ThemeData`
  factory; `colorSchemeSeed: Colors.teal` (Material teal, `#009688`) with
  `useMaterial3: true`; no `darkTheme` sibling
- `lib/main.dart:38` — `MaterialApp.theme: habbitsTheme()`; no `darkTheme` or
  `themeMode` argument; Flutter falls back to `ThemeMode.system` by default
- `lib/ui/habit_list/widgets/habit_card.dart:50` — `Theme.of(context).textTheme.titleMedium` for habit name; line 64 — `Theme.of(context).colorScheme.onSurfaceVariant` for drag handle
- `lib/ui/habit_detail/habit_detail_screen.dart:74` — `Theme.of(context).textTheme.titleMedium` for stats labels
- `lib/ui/widgets/heatmap_grid.dart:25` — `_cellColor`: completed → `color`; not-completed → `color.withValues(alpha: 0.15)`; future → `Colors.transparent`; `color` is the per-habit `Color` value, not a `ColorScheme` token
- `lib/ui/widgets/day_strip.dart:39` — same intensity pattern as `HeatmapGrid`
- `lib/data/repositories/settings_repository.dart` — persists only the locale token; no theme-mode key (see [`i18n.md`](i18n.md))

## Invariants

- All chrome colors (text, icons, surfaces) come from `Theme.of(context)` —
  no hex literals in widget files.
- The brand/seed color is `Colors.teal` (`#009688`), defined in one place
  (`theme.dart:3`) and also used as the app-icon background in
  `assets/icon/icon.svg`.
- `MaterialApp` sets `theme` only; no `darkTheme` is provided, so the light
  theme is always rendered — device brightness has no effect.
- There is no user-settable theme-mode preference and no persistence of one;
  `SettingsRepository` stores only the locale.

## Known edges

- No dark theme: `MaterialApp` sets `theme` only (`lib/main.dart:38`); the app has no dark mode. (tracked in deferred.md)
- Per-habit activity colors (`Color(habit.color)`) in `heatmap_grid.dart` (inactive cells `withValues(alpha: 0.15)`, line ~30) and `day_strip.dart` (~line 39) are drawn directly and do not adapt to a dark surface. (tracked in deferred.md)

## History

Seed color and `habbitsTheme()` established by the foundation slice; the
activity-grid app icon adopted the same teal in:
[2026-06-13.03-usability-v2](../planning/changes/archive/2026-06-13.03-usability-v2/design.md),
[2026-06-15.02-app-icon-branding](../planning/changes/archive/2026-06-15.02-app-icon-branding/design.md)

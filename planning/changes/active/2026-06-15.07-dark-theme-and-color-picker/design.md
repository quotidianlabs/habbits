---
status: draft
date: 2026-06-15
slug: dark-theme-and-color-picker
supersedes: null
superseded_by: null
pr: null
outcome: null
---

# Design: Dark theme + per-habit color picker

## Summary

Two related color capabilities shipped as one bundle. First, an app-wide dark
theme with a System / Light / Dark selector in Settings, persisted like the
existing language preference; the activity grids (heatmap, day strip) are made
dark-surface adaptive so inactive cells stay visible. Second, a per-habit color
picker — a curated swatch palette — on both create and edit, replacing the
silently-defaulted teal.

## Motivation

Both items are pre-identified edges in `architecture/theming.md` ("Known edges")
and tracked in `planning/deferred.md`:

- The app has **no dark mode**: `MaterialApp` sets `theme` only
  (`lib/main.dart:38`), so the light teal palette renders regardless of device
  brightness.
- Per-habit activity colors in `heatmap_grid.dart` / `day_strip.dart` are drawn
  as `color.withValues(alpha: 0.15)` over the background — a near-invisible tint
  on a dark surface, so they will not adapt when dark mode lands. The two items
  are coupled: dark mode is incomplete without fixing the grids.
- The create/edit dialog (`habit_dialogs.dart`) collects only the name; color is
  defaulted to teal in the view model (`kDefaultHabitColor`), so every habit is
  the same color and the user cannot choose. Folding the picker in here is
  natural because both features are about color reading well on both surfaces.

## Non-goals

- No arbitrary color picking (HSV wheel / RGB sliders) — a curated palette only,
  so every choice is vetted to read on both light and dark surfaces and no new
  dependency is added.
- No theming of the per-habit *brand* color by theme mode — a habit keeps its
  one stored color; only the surrounding chrome and the inactive-cell tint adapt.
- No automatic schedule-based ("sunset") theme switching beyond `ThemeMode.system`.
- No migration of existing habits' colors — they keep their stored value.

## Design

### 1. Theme definitions (`lib/ui/core/theme.dart`)

Replace the single `habbitsTheme()` with two factories:

```dart
ThemeData habbitsLightTheme() => ThemeData(
  colorSchemeSeed: Colors.teal, useMaterial3: true, brightness: Brightness.light);
ThemeData habbitsDarkTheme() => ThemeData(
  colorSchemeSeed: Colors.teal, useMaterial3: true, brightness: Brightness.dark);
```

Material 3 derives a coherent dark palette from the existing teal seed; no
hand-tuned hex. The teal seed remains the single brand-color source of truth.

### 2. Theme preference + persistence

Mirror the locale pattern exactly.

- New `lib/ui/core/theme_controller.dart` with an `AppThemeMode` enum:

  ```dart
  enum AppThemeMode {
    system('system', ThemeMode.system),
    light('light', ThemeMode.light),
    dark('dark', ThemeMode.dark);
    const AppThemeMode(this.storage, this.themeMode);
    final String storage;
    final ThemeMode themeMode;
    static AppThemeMode fromStorage(String? value) =>
        AppThemeMode.values.firstWhere((e) => e.storage == value,
            orElse: () => AppThemeMode.system);
  }
  ```

- `@Riverpod(keepAlive: true) ThemeController` with `build()` reading
  `settingsRepository.readThemeToken()` and `set(AppThemeMode)` writing the
  token then updating `state` — byte-for-byte the shape of `LocaleController`.
- `SettingsRepository` gains `static const _themeKey = 'theme';`,
  `String? readThemeToken()` and `Future<void> writeThemeToken(String token)`.

### 3. Wiring (`lib/main.dart`)

`HabbitsApp` watches `themeControllerProvider` and sets:

```dart
theme: habbitsLightTheme(),
darkTheme: habbitsDarkTheme(),
themeMode: ref.watch(themeControllerProvider).themeMode,
```

Default token = `system`, so behavior is unchanged for users who never open the
selector but the app now follows device brightness.

### 4. Theme selector in Settings (`lib/ui/settings/settings_screen.dart`)

A new tile + `SimpleDialog` mirroring the language tile / `_pickLanguage`:

- Tile key `theme-tile`, leading `Icons.brightness_6`, title `l10n.theme`,
  subtitle the current mode's display name.
- Dialog options keyed `theme-option-<token>`, check mark on the current one,
  `onTap` → `themeControllerProvider.notifier.set(option)`.
- A `_themeName(l10n, mode)` switch like `_localeName`.

### 5. Dark-surface-adaptive activity cells

The inactive-cell color is the only non-chrome color that fails on dark. Extract
a pure helper so it is unit-testable without a widget:

```dart
// lib/ui/core/habit_colors.dart (or theme.dart)
Color inactiveCellColor(Color habitColor, ColorScheme scheme) =>
    Color.alphaBlend(
      habitColor.withValues(alpha: scheme.brightness == Brightness.dark ? 0.30 : 0.15),
      scheme.surface,
    );
```

Compositing the tint over the *actual* theme surface (not the implicit
background) yields an opaque color that is visible on both brightnesses; the
higher dark-mode alpha compensates for the dark surface. `heatmap_grid.dart` and
`day_strip.dart` read `Theme.of(context).colorScheme` and call this for the
not-completed state; completed cells stay full `habitColor`, future cells stay
`Colors.transparent`.

### 6. Curated habit palette (`lib/ui/core/habit_colors.dart`)

`const List<int> kHabitPalette` of ~10 colors hand-picked to read on both
surfaces, teal (`0xFF009688`) first. `kDefaultHabitColor` stays and equals
`kHabitPalette.first`. (Move `kDefaultHabitColor` here from the view model so
palette + default live together; update the import in `habit_list_view_model.dart`.)

### 7. Color picker in the create/edit dialog (`lib/ui/widgets/habit_dialogs.dart`)

`showHabitNameDialog` returns a small result instead of `String?`:

```dart
class HabitFormResult {
  const HabitFormResult(this.name, this.color);
  final String name;
  final int color;
}
Future<HabitFormResult?> showHabitNameDialog(BuildContext context,
    {String? initialName, int? initialColor, bool isRename = false});
```

The dialog body becomes a small `StatefulWidget` holding the selected color (and
owning the `TextEditingController`, so it is **disposed** in `dispose()` —
clearing the deferred controller-leak item). Below the name field, a `Wrap` of
selectable swatch dots from `kHabitPalette`, each keyed `habit-color-<hex>`, with
a check mark / ring on the selected one. `initialColor` defaults to the habit's
current color on edit and `kDefaultHabitColor` on create. Cancel or empty name
still returns `null`.

### 8. Edit-color mutation path

There is no update-color seam today (`renameHabit` only changes the name), so add
one through the layers:

- `HabitDao.setColor(int id, int color)`.
- `HabitRepository.setColor(int id, int color)`.
- `HabitDetailViewModel`: replace `rename(name)` with
  `editHabit(String name, int color)` that calls `renameHabit` and `setColor`
  for whatever changed.

### 9. Call sites

- `habit_list_screen.dart` create: `showHabitNameDialog(context)` →
  `createHabit(result.name, color: result.color)`.
- `habit_detail_screen.dart` edit: pass `initialName` + `initialColor` in, call
  `editHabit(result.name, result.color)` out.

### 10. i18n

Add `theme`, `themeSystem`, `themeLight`, `themeDark`, and `color` (swatch-group
label) to `app_en.arb` + `app_ru.arb`; reuse existing `newHabit` / `renameHabit`
/ `save` / `cancel`. Regenerate `app_localizations*`.

## Testing

- **Unit**: `AppThemeMode.fromStorage` round-trips every token + unknown→system;
  `SettingsRepository` theme token read/write; `inactiveCellColor` differs by
  brightness and is opaque (alpha == 255).
- **Widget**: theme selector tile opens the dialog and `set()` flips
  `themeMode`; the color dialog returns the chosen swatch and pre-selects
  `initialColor`; the detail "edit" flow applies a new color; heatmap and day
  strip render a distinguishable inactive cell under a dark `ThemeData`.
- `just lint` + `just test` green; run `build_runner` after the new `@riverpod`
  controller and any DAO change.

## Risk

- **Low — dark palette legibility.** M3-generated dark scheme is conservative;
  the curated palette caps per-habit color risk. Mitigation: the widget test
  asserts a visible inactive cell on dark.
- **Low — dialog return-type change** ripples to two call sites and the detail
  VM; both are updated in this bundle and covered by widget tests.
- **Low — `build_runner` drift**: the new controller and DAO method require
  regenerating `*.g.dart`; the plan sequences it explicitly.

## Docs

On merge, promote into `architecture/theming.md` (drop both "Known edges";
document light+dark themes, the selector + persistence, and adaptive cells) and
`architecture/habit-tracking.md` (color is now user-chosen on create/edit).
Clear the three resolved `deferred.md` items (no dark theme; non-adaptive cells;
color picker) and the `TextEditingController` disposal item. Archive the bundle.

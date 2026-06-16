---
status: shipped
date: 2026-06-15
slug: dark-theme-and-color-picker
spec: dark-theme-and-color-picker
pr: 6
---

# dark-theme-and-color-picker — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps
> use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship an app-wide dark theme with a System/Light/Dark selector and
dark-adaptive activity grids, plus a curated per-habit color picker on
create/edit.

**Spec:** [`design.md`](./design.md)

**Branch:** `feat/dark-theme-and-color-picker` (already checked out).

**Commit strategy:** Per-task commits. After any task touching a `@riverpod`
class, run `dart run build_runner build --delete-conflicting-outputs` and
include the regenerated `*.g.dart` in that task's commit. Every task ends green
on `just test`.

**Group A (Tasks 1–7)** delivers dark theme end to end. **Group B (Tasks 8–13)**
delivers the color picker. Each task is independently shippable.

---

### Task 1: Split the theme into light + dark factories

**Files:**
- Modify: `lib/ui/core/theme.dart`
- Test: `test/ui/core/theme_test.dart` (create)

Replace the single `habbitsTheme()` with brightness-specific factories built
from the same teal seed.

- [ ] **Step 1: Write the failing test**

  Create `test/ui/core/theme_test.dart`:

  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:habbits/ui/core/theme.dart';

  void main() {
    test('light theme is Material 3 and light', () {
      final t = habbitsLightTheme();
      expect(t.useMaterial3, isTrue);
      expect(t.brightness, Brightness.light);
    });

    test('dark theme is Material 3 and dark', () {
      final t = habbitsDarkTheme();
      expect(t.useMaterial3, isTrue);
      expect(t.brightness, Brightness.dark);
    });
  }
  ```

- [ ] **Step 2: Run the test, verify it fails**

  Run: `flutter test test/ui/core/theme_test.dart`
  Expected: FAIL — `habbitsLightTheme`/`habbitsDarkTheme` undefined.

- [ ] **Step 3: Implement the factories**

  Replace the body of `lib/ui/core/theme.dart`:

  ```dart
  import 'package:flutter/material.dart';

  ThemeData habbitsLightTheme() => ThemeData(
    colorSchemeSeed: Colors.teal,
    useMaterial3: true,
    brightness: Brightness.light,
  );

  ThemeData habbitsDarkTheme() => ThemeData(
    colorSchemeSeed: Colors.teal,
    useMaterial3: true,
    brightness: Brightness.dark,
  );
  ```

- [ ] **Step 4: Update the call site in `main.dart`**

  In `lib/main.dart`, change `theme: habbitsTheme(),` to:

  ```dart
        theme: habbitsLightTheme(),
        darkTheme: habbitsDarkTheme(),
  ```

  (Leave `themeMode` unset for now — Flutter defaults to `ThemeMode.system`, so
  the app already follows device brightness after this task.)

- [ ] **Step 5: Run the test + analyzer, verify pass**

  Run: `flutter test test/ui/core/theme_test.dart && flutter analyze`
  Expected: PASS, no analyzer issues.

- [ ] **Step 6: Commit**

  ```bash
  git add lib/ui/core/theme.dart lib/main.dart test/ui/core/theme_test.dart
  git commit -m "feat(theme): light + dark ThemeData factories from teal seed

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 2: Add the theme token to SettingsRepository

**Files:**
- Modify: `lib/data/repositories/settings_repository.dart`
- Test: `test/data/repositories/settings_repository_test.dart`

Add a `theme` key with read/write methods mirroring the locale token.

- [ ] **Step 1: Write the failing test**

  Append inside `main()` in `test/data/repositories/settings_repository_test.dart`:

  ```dart
    test('reads and writes the theme token', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SettingsRepository(await SharedPreferences.getInstance());
      expect(repo.readThemeToken(), isNull);
      await repo.writeThemeToken('dark');
      expect(repo.readThemeToken(), 'dark');
    });
  ```

- [ ] **Step 2: Run the test, verify it fails**

  Run: `flutter test test/data/repositories/settings_repository_test.dart`
  Expected: FAIL — `readThemeToken`/`writeThemeToken` undefined.

- [ ] **Step 3: Implement**

  In `lib/data/repositories/settings_repository.dart`, add the key constant and
  two methods alongside the locale ones:

  ```dart
    static const _themeKey = 'theme';

    String? readThemeToken() => _prefs.getString(_themeKey);
    Future<void> writeThemeToken(String token) =>
        _prefs.setString(_themeKey, token);
  ```

- [ ] **Step 4: Run the test, verify pass**

  Run: `flutter test test/data/repositories/settings_repository_test.dart`
  Expected: PASS.

- [ ] **Step 5: Commit**

  ```bash
  git add lib/data/repositories/settings_repository.dart test/data/repositories/settings_repository_test.dart
  git commit -m "feat(settings): persist a theme token

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 3: AppThemeMode enum + ThemeController

**Files:**
- Create: `lib/ui/core/theme_controller.dart`
- Create: `lib/ui/core/theme_controller.g.dart` (generated)
- Test: `test/ui/core/theme_controller_test.dart` (create)

Mirror `LocaleController`/`AppLocale` exactly.

- [ ] **Step 1: Write the failing test**

  Create `test/ui/core/theme_controller_test.dart`:

  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:habbits/data/repositories/settings_repository.dart';
  import 'package:habbits/ui/core/theme_controller.dart';
  import 'package:shared_preferences/shared_preferences.dart';

  Future<ProviderContainer> _container(Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return c;
  }

  void main() {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('fromStorage falls back to system on null/unknown', () {
      expect(AppThemeMode.fromStorage(null), AppThemeMode.system);
      expect(AppThemeMode.fromStorage('xx'), AppThemeMode.system);
      expect(AppThemeMode.fromStorage('light'), AppThemeMode.light);
      expect(AppThemeMode.fromStorage('dark'), AppThemeMode.dark);
    });

    test('maps to Flutter ThemeMode', () {
      expect(AppThemeMode.system.themeMode, ThemeMode.system);
      expect(AppThemeMode.light.themeMode, ThemeMode.light);
      expect(AppThemeMode.dark.themeMode, ThemeMode.dark);
    });

    test('defaults to system when nothing stored', () async {
      final c = await _container({});
      expect(c.read(themeControllerProvider), AppThemeMode.system);
    });

    test('reads a persisted value', () async {
      final c = await _container({'theme': 'dark'});
      expect(c.read(themeControllerProvider), AppThemeMode.dark);
    });

    test('set persists to prefs and updates state', () async {
      final c = await _container({});
      await c.read(themeControllerProvider.notifier).set(AppThemeMode.dark);
      expect(c.read(themeControllerProvider), AppThemeMode.dark);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme'), 'dark');
    });
  }
  ```

- [ ] **Step 2: Implement the controller**

  Create `lib/ui/core/theme_controller.dart`:

  ```dart
  import 'package:flutter/material.dart';
  import 'package:riverpod_annotation/riverpod_annotation.dart';

  import '../../data/repositories/settings_repository.dart';

  part 'theme_controller.g.dart';

  /// The user's theme choice. [system] follows the device brightness.
  enum AppThemeMode {
    system('system', ThemeMode.system),
    light('light', ThemeMode.light),
    dark('dark', ThemeMode.dark);

    const AppThemeMode(this.storage, this.themeMode);

    /// Stable token persisted to shared_preferences.
    final String storage;

    /// The Flutter [ThemeMode] this choice maps to.
    final ThemeMode themeMode;

    static AppThemeMode fromStorage(String? value) =>
        AppThemeMode.values.firstWhere(
          (e) => e.storage == value,
          orElse: () => AppThemeMode.system,
        );
  }

  /// Holds the selected [AppThemeMode], backed by shared_preferences.
  @Riverpod(keepAlive: true)
  class ThemeController extends _$ThemeController {
    @override
    AppThemeMode build() => AppThemeMode.fromStorage(
      ref.watch(settingsRepositoryProvider).readThemeToken(),
    );

    Future<void> set(AppThemeMode value) async {
      await ref.read(settingsRepositoryProvider).writeThemeToken(value.storage);
      state = value;
    }
  }
  ```

- [ ] **Step 3: Generate the Riverpod code**

  Run: `dart run build_runner build --delete-conflicting-outputs`
  Expected: writes `lib/ui/core/theme_controller.g.dart`, no errors.

- [ ] **Step 4: Run the test, verify pass**

  Run: `flutter test test/ui/core/theme_controller_test.dart`
  Expected: PASS (all 5).

- [ ] **Step 5: Commit**

  ```bash
  git add lib/ui/core/theme_controller.dart lib/ui/core/theme_controller.g.dart test/ui/core/theme_controller_test.dart
  git commit -m "feat(theme): ThemeController + AppThemeMode, backed by settings

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 4: Wire ThemeController into MaterialApp

**Files:**
- Modify: `lib/main.dart`

`themeMode` now follows the persisted preference, not just the device.

- [ ] **Step 1: Edit `main.dart`**

  Add the import:

  ```dart
  import 'ui/core/theme_controller.dart';
  ```

  In `HabbitsApp.build`, add below the `appLocale` line:

  ```dart
      final themeMode = ref.watch(themeControllerProvider);
  ```

  And add to the `MaterialApp` (it already has `theme:`/`darkTheme:` from Task 1):

  ```dart
        themeMode: themeMode.themeMode,
  ```

- [ ] **Step 2: Verify analyzer + full test run**

  Run: `flutter analyze && flutter test`
  Expected: no issues; all tests pass.

- [ ] **Step 3: Commit**

  ```bash
  git add lib/main.dart
  git commit -m "feat(theme): drive MaterialApp.themeMode from ThemeController

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 5: Theme strings in l10n

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_ru.arb`
- Modify (generated): `lib/l10n/app_localizations*.dart`

Add the selector strings used by Task 6.

- [ ] **Step 1: Add English strings**

  In `lib/l10n/app_en.arb`, add these keys (anywhere among the existing
  entries, keeping valid JSON):

  ```json
    "theme": "Theme",
    "themeSystem": "System",
    "themeLight": "Light",
    "themeDark": "Dark",
    "color": "Color",
  ```

- [ ] **Step 2: Add Russian strings**

  In `lib/l10n/app_ru.arb`, add:

  ```json
    "theme": "Тема",
    "themeSystem": "Системная",
    "themeLight": "Светлая",
    "themeDark": "Тёмная",
    "color": "Цвет",
  ```

- [ ] **Step 3: Regenerate localizations**

  Run: `flutter gen-l10n`
  Expected: updates `lib/l10n/app_localizations*.dart` with the new getters.

- [ ] **Step 4: Verify analyzer**

  Run: `flutter analyze`
  Expected: no issues.

- [ ] **Step 5: Commit**

  ```bash
  git add lib/l10n/
  git commit -m "i18n: theme selector + color strings (en/ru)

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 6: Theme selector tile in Settings

**Files:**
- Modify: `lib/ui/settings/settings_screen.dart`
- Test: `test/ui/settings_screen_test.dart`

A tile + `SimpleDialog` mirroring the language picker.

- [ ] **Step 1: Write the failing widget test**

  Append inside `main()` in `test/ui/settings_screen_test.dart`:

  ```dart
    testWidgets('theme picker switches to dark and persists', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('theme-tile')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('theme-option-system')),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('theme-option-dark')));
      await tester.pumpAndSettle();
      expect(prefs.getString('theme'), 'dark');
    });
  ```

  Add the import at the top of the file:

  ```dart
  import 'package:habbits/ui/core/theme_controller.dart';
  ```

- [ ] **Step 2: Run the test, verify it fails**

  Run: `flutter test test/ui/settings_screen_test.dart`
  Expected: FAIL — no `theme-tile`.

- [ ] **Step 3: Add the tile + picker**

  In `lib/ui/settings/settings_screen.dart`, add the import:

  ```dart
  import '../core/theme_controller.dart';
  ```

  Add a tile in the `ListView`, after the language `Consumer` block:

  ```dart
            Consumer(
              builder: (context, ref, _) {
                final current = ref.watch(themeControllerProvider);
                return ListTile(
                  key: const Key('theme-tile'),
                  leading: const Icon(Icons.brightness_6),
                  title: Text(l10n.theme),
                  subtitle: Text(_themeName(l10n, current)),
                  onTap: () => _pickTheme(context, ref, current),
                );
              },
            ),
  ```

  Add these top-level helpers next to `_localeName`/`_pickLanguage`:

  ```dart
  String _themeName(AppLocalizations l10n, AppThemeMode mode) => switch (mode) {
    AppThemeMode.system => l10n.themeSystem,
    AppThemeMode.light => l10n.themeLight,
    AppThemeMode.dark => l10n.themeDark,
  };

  Future<void> _pickTheme(
    BuildContext context,
    WidgetRef ref,
    AppThemeMode current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final chosen = await showDialog<AppThemeMode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.theme),
        children: [
          for (final option in AppThemeMode.values)
            ListTile(
              key: Key('theme-option-${option.storage}'),
              title: Text(_themeName(l10n, option)),
              trailing: option == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, option),
            ),
        ],
      ),
    );
    if (chosen != null) {
      await ref.read(themeControllerProvider.notifier).set(chosen);
    }
  }
  ```

- [ ] **Step 4: Run the test, verify pass**

  Run: `flutter test test/ui/settings_screen_test.dart`
  Expected: PASS.

- [ ] **Step 5: Commit**

  ```bash
  git add lib/ui/settings/settings_screen.dart test/ui/settings_screen_test.dart
  git commit -m "feat(settings): System/Light/Dark theme selector tile

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 7: Dark-adaptive activity cells

**Files:**
- Create: `lib/ui/core/habit_colors.dart`
- Modify: `lib/ui/widgets/heatmap_grid.dart`
- Modify: `lib/ui/widgets/day_strip.dart`
- Test: `test/ui/core/habit_colors_test.dart` (create)
- Test: `test/ui/heatmap_grid_test.dart`

Inactive cells composite over the theme surface so they stay visible on dark.

- [ ] **Step 1: Write the failing helper test**

  Create `test/ui/core/habit_colors_test.dart`:

  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:habbits/ui/core/habit_colors.dart';

  void main() {
    const habit = Color(0xFF009688);

    test('inactive cell is opaque on both brightnesses', () {
      final light = ColorScheme.fromSeed(seedColor: Colors.teal);
      final dark = ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      );
      expect(inactiveCellColor(habit, light).a, 1.0);
      expect(inactiveCellColor(habit, dark).a, 1.0);
    });

    test('inactive cell differs between light and dark surfaces', () {
      final light = ColorScheme.fromSeed(seedColor: Colors.teal);
      final dark = ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      );
      expect(
        inactiveCellColor(habit, light),
        isNot(inactiveCellColor(habit, dark)),
      );
    });
  }
  ```

- [ ] **Step 2: Run the test, verify it fails**

  Run: `flutter test test/ui/core/habit_colors_test.dart`
  Expected: FAIL — `inactiveCellColor` undefined.

- [ ] **Step 3: Implement the helper**

  Create `lib/ui/core/habit_colors.dart`:

  ```dart
  import 'package:flutter/material.dart';

  /// Default color for a newly created habit (Material teal).
  const int kDefaultHabitColor = 0xFF009688;

  /// Curated habit colors, each vetted to read on light and dark surfaces.
  /// [kDefaultHabitColor] (teal) is first.
  const List<int> kHabitPalette = [
    0xFF009688, // teal
    0xFF1E88E5, // blue
    0xFF5E35B1, // deep purple
    0xFFD81B60, // pink
    0xFFE53935, // red
    0xFFF4511E, // deep orange
    0xFFFB8C00, // orange
    0xFF43A047, // green
    0xFF00897B, // teal-green
    0xFF6D4C41, // brown
  ];

  /// The color for a not-completed activity cell of a habit colored
  /// [habitColor], composited over [scheme.surface] so it is opaque and
  /// visible on either brightness. Dark surfaces use a stronger tint.
  Color inactiveCellColor(Color habitColor, ColorScheme scheme) =>
      Color.alphaBlend(
        habitColor.withValues(
          alpha: scheme.brightness == Brightness.dark ? 0.30 : 0.15,
        ),
        scheme.surface,
      );
  ```

- [ ] **Step 4: Run the helper test, verify pass**

  Run: `flutter test test/ui/core/habit_colors_test.dart`
  Expected: PASS.

- [ ] **Step 5: Use the helper in `heatmap_grid.dart`**

  In `lib/ui/widgets/heatmap_grid.dart`, add the import:

  ```dart
  import '../core/habit_colors.dart';
  ```

  Change `_cellColor` to take the scheme, and pass it from `build`/`_grid`.
  Replace the `_cellColor` method:

  ```dart
    Color _cellColor(CellState state, ColorScheme scheme) {
      switch (state) {
        case CellState.completed:
          return color;
        case CellState.notCompleted:
          return inactiveCellColor(color, scheme);
        case CellState.future:
          return Colors.transparent;
      }
    }
  ```

  `_grid` and `_labelsRow` are called from `build`, which has `context`. Change
  `_grid()` to `_grid(ColorScheme scheme)` and use the cell color via
  `_cellColor(cell.state, scheme)`. In `build`, compute
  `final scheme = Theme.of(context).colorScheme;` at the top and pass it:
  - `if (!showMonthLabels) return _grid(scheme);`
  - `children: [_labelsRow(localeName), _grid(scheme)],`

- [ ] **Step 6: Use the helper in `day_strip.dart`**

  In `lib/ui/widgets/day_strip.dart`, add the import:

  ```dart
  import '../core/habit_colors.dart';
  ```

  In `build`, compute `final scheme = Theme.of(context).colorScheme;` and change
  the cell decoration color from
  `day.completed ? color : color.withValues(alpha: 0.15)` to:

  ```dart
                color: day.completed ? color : inactiveCellColor(color, scheme),
  ```

- [ ] **Step 7: Add a dark-render widget test**

  Append inside `main()` in `test/ui/heatmap_grid_test.dart` (reuse that file's
  existing imports for `HeatmapGrid`/`buildHeatmap`; add
  `import 'package:flutter/material.dart';` if absent):

  ```dart
    testWidgets('renders under a dark theme without error', (tester) async {
      final data = buildHeatmap(
        completed: {DateTime(2026, 6, 10)},
        today: DateTime(2026, 6, 15),
        weeks: 2,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
          home: Scaffold(
            body: HeatmapGrid(data: data, color: const Color(0xFF009688)),
          ),
        ),
      );
      expect(find.byType(HeatmapGrid), findsOneWidget);
    });
  ```

- [ ] **Step 8: Run the relevant tests + analyzer, verify pass**

  Run: `flutter test test/ui/heatmap_grid_test.dart test/ui/day_strip_test.dart test/ui/core/habit_colors_test.dart && flutter analyze`
  Expected: PASS, no issues.

- [ ] **Step 9: Commit**

  ```bash
  git add lib/ui/core/habit_colors.dart lib/ui/widgets/heatmap_grid.dart lib/ui/widgets/day_strip.dart test/ui/core/habit_colors_test.dart test/ui/heatmap_grid_test.dart
  git commit -m "feat(theme): dark-surface-adaptive activity cells + curated palette

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 8: Point kDefaultHabitColor at the shared constant

**Files:**
- Modify: `lib/ui/habit_list/habit_list_view_model.dart`

`kDefaultHabitColor` now lives in `habit_colors.dart` (Task 7); remove the
duplicate so there is one source of truth.

- [ ] **Step 1: Edit the view model**

  In `lib/ui/habit_list/habit_list_view_model.dart`, delete the local constant:

  ```dart
  /// Default color for a newly created habit (Material teal).
  const int kDefaultHabitColor = 0xFF009688;
  ```

  and add the import so existing references still resolve:

  ```dart
  import '../core/habit_colors.dart';
  ```

  (`createHabit`'s `{int color = kDefaultHabitColor}` default keeps working via
  the import.)

- [ ] **Step 2: Verify analyzer + tests**

  Run: `flutter analyze && flutter test test/ui/habit_list/habit_list_view_model_test.dart`
  Expected: no issues; tests pass.

- [ ] **Step 3: Commit**

  ```bash
  git add lib/ui/habit_list/habit_list_view_model.dart
  git commit -m "refactor: single source for kDefaultHabitColor

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 9: setColor through DAO + repository

**Files:**
- Modify: `lib/data/services/database/habit_dao.dart`
- Modify: `lib/data/repositories/habit_repository.dart`
- Test: `test/data/services/database/habit_dao_test.dart`

Add the missing update-color seam.

- [ ] **Step 1: Write the failing DAO test**

  Append inside `main()` in `test/data/services/database/habit_dao_test.dart`
  (reuse the file's existing `AppDatabase`/`NativeDatabase.memory()` setup
  pattern):

  ```dart
    test('setColor updates only the color', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await db.habitDao.createHabit(name: 'Read', color: 0xFF009688);
      await db.habitDao.setColor(id, 0xFFE53935);
      final rows = await db.habitDao.getHabitsWithDates();
      expect(rows.single.habit.color, 0xFFE53935);
      expect(rows.single.habit.name, 'Read');
    });
  ```

  (If `habit_dao_test.dart` lacks the drift imports, add
  `import 'package:drift/native.dart';` and
  `import 'package:habbits/data/services/database/database.dart';`.)

- [ ] **Step 2: Run the test, verify it fails**

  Run: `flutter test test/data/services/database/habit_dao_test.dart`
  Expected: FAIL — `setColor` undefined.

- [ ] **Step 3: Implement in the DAO**

  In `lib/data/services/database/habit_dao.dart`, add next to `renameHabit`:

  ```dart
    Future<void> setColor(int id, int color) {
      return (update(habits)..where((h) => h.id.equals(id))).write(
        HabitsCompanion(color: Value(color)),
      );
    }
  ```

- [ ] **Step 4: Expose it on the repository**

  In `lib/data/repositories/habit_repository.dart`, add next to `renameHabit`:

  ```dart
    Future<void> setColor(int id, int color) => _dao.setColor(id, color);
  ```

- [ ] **Step 5: Run the test, verify pass**

  Run: `flutter test test/data/services/database/habit_dao_test.dart`
  Expected: PASS.

- [ ] **Step 6: Commit**

  ```bash
  git add lib/data/services/database/habit_dao.dart lib/data/repositories/habit_repository.dart test/data/services/database/habit_dao_test.dart
  git commit -m "feat(data): setColor on HabitDao + HabitRepository

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 10: editHabit on the detail view model

**Files:**
- Modify: `lib/ui/habit_detail/habit_detail_view_model.dart`
- Test: `test/ui/habit_detail/habit_detail_view_model_test.dart`

Replace `rename` with `editHabit(name, color)` applying only what changed.

- [ ] **Step 1: Write the failing test**

  Append inside `main()` in
  `test/ui/habit_detail/habit_detail_view_model_test.dart` (reuse that file's
  existing container/db setup; model the new test on its existing `rename`
  test):

  ```dart
    test('editHabit updates name and color', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await db.habitDao.createHabit(name: 'Old', color: 0xFF009688);
      final c = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(c.dispose);
      // ensure the list stream has emitted before editing
      await c.read(habitListViewModelProvider.future);
      await c
          .read(habitDetailViewModelProvider(id).notifier)
          .editHabit('New', 0xFFE53935);
      final rows = await db.habitDao.getHabitsWithDates();
      expect(rows.single.habit.name, 'New');
      expect(rows.single.habit.color, 0xFFE53935);
    });
  ```

  (Match the imports already used by the existing tests in this file —
  `appDatabaseProvider`, `habitListViewModelProvider`,
  `habitDetailViewModelProvider`, drift, etc.)

- [ ] **Step 2: Run the test, verify it fails**

  Run: `flutter test test/ui/habit_detail/habit_detail_view_model_test.dart`
  Expected: FAIL — `editHabit` undefined.

- [ ] **Step 3: Implement**

  In `lib/ui/habit_detail/habit_detail_view_model.dart`, replace the `rename`
  method with:

  ```dart
    Future<void> editHabit(String name, int color) async {
      final repo = ref.read(habitRepositoryProvider);
      await repo.renameHabit(habitId, name);
      await repo.setColor(habitId, color);
    }
  ```

- [ ] **Step 4: Run the test, verify pass**

  Run: `flutter test test/ui/habit_detail/habit_detail_view_model_test.dart`
  Expected: PASS. (If an existing test referenced `.rename`, update it to
  `.editHabit(name, existingColor)`.)

- [ ] **Step 5: Commit**

  ```bash
  git add lib/ui/habit_detail/habit_detail_view_model.dart test/ui/habit_detail/habit_detail_view_model_test.dart
  git commit -m "feat(detail): editHabit(name, color) replaces rename

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 11: Name+color dialog with a swatch picker

**Files:**
- Modify: `lib/ui/widgets/habit_dialogs.dart`
- Test: `test/ui/habit_dialogs_test.dart` (create)

`showHabitNameDialog` returns `HabitFormResult(name, color)`; the body is a
`StatefulWidget` that owns and disposes the controller.

- [ ] **Step 1: Write the failing widget test**

  Create `test/ui/habit_dialogs_test.dart`:

  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:habbits/l10n/app_localizations.dart';
  import 'package:habbits/ui/core/habit_colors.dart';
  import 'package:habbits/ui/widgets/habit_dialogs.dart';

  void main() {
    testWidgets('returns entered name and chosen swatch', (tester) async {
      HabitFormResult? result;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('open'),
                onPressed: () async {
                  result = await showHabitNameDialog(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('habit-name-field')), 'Run');
      final second = kHabitPalette[1];
      await tester.tap(
        find.byKey(Key('habit-color-${second.toRadixString(16)}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('habit-name-confirm')));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.name, 'Run');
      expect(result!.color, second);
    });
  }
  ```

- [ ] **Step 2: Run the test, verify it fails**

  Run: `flutter test test/ui/habit_dialogs_test.dart`
  Expected: FAIL — `HabitFormResult` / new signature undefined.

- [ ] **Step 3: Rewrite `habit_dialogs.dart`**

  Replace the `showHabitNameDialog` function (keep `confirmDeleteHabit`
  unchanged) in `lib/ui/widgets/habit_dialogs.dart`. Add imports at the top:

  ```dart
  import '../core/habit_colors.dart';
  ```

  New code:

  ```dart
  /// The result of the create/edit dialog: the trimmed name + chosen color.
  class HabitFormResult {
    const HabitFormResult(this.name, this.color);
    final String name;
    final int color;
  }

  /// Shows the create/edit dialog. Returns the [HabitFormResult], or null if the
  /// user cancelled or entered nothing. [initialName]/[initialColor] pre-fill the
  /// fields (edit). [isRename] only switches the title.
  Future<HabitFormResult?> showHabitNameDialog(
    BuildContext context, {
    String? initialName,
    int? initialColor,
    bool isRename = false,
  }) {
    return showDialog<HabitFormResult>(
      context: context,
      builder: (ctx) => _HabitFormDialog(
        initialName: initialName ?? '',
        initialColor: initialColor ?? kDefaultHabitColor,
        isRename: isRename,
      ),
    );
  }

  class _HabitFormDialog extends StatefulWidget {
    const _HabitFormDialog({
      required this.initialName,
      required this.initialColor,
      required this.isRename,
    });
    final String initialName;
    final int initialColor;
    final bool isRename;

    @override
    State<_HabitFormDialog> createState() => _HabitFormDialogState();
  }

  class _HabitFormDialogState extends State<_HabitFormDialog> {
    late final TextEditingController _controller =
        TextEditingController(text: widget.initialName);
    late int _color = widget.initialColor;

    @override
    void dispose() {
      _controller.dispose();
      super.dispose();
    }

    void _submit() {
      final name = _controller.text.trim();
      if (name.isEmpty) {
        Navigator.pop(context);
        return;
      }
      Navigator.pop(context, HabitFormResult(name, _color));
    }

    @override
    Widget build(BuildContext context) {
      final l10n = AppLocalizations.of(context);
      return AlertDialog(
        title: Text(widget.isRename ? l10n.renameHabit : l10n.newHabit),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('habit-name-field'),
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.nameLabel),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            Text(l10n.color),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in kHabitPalette)
                  GestureDetector(
                    key: Key('habit-color-${value.toRadixString(16)}'),
                    onTap: () => setState(() => _color = value),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(value),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.onSurface,
                          width: value == _color ? 3 : 0,
                        ),
                      ),
                      child: value == _color
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const Key('habit-name-confirm'),
            onPressed: _submit,
            child: Text(l10n.save),
          ),
        ],
      );
    }
  }
  ```

- [ ] **Step 4: Run the test, verify pass**

  Run: `flutter test test/ui/habit_dialogs_test.dart`
  Expected: PASS.

- [ ] **Step 5: Commit**

  ```bash
  git add lib/ui/widgets/habit_dialogs.dart test/ui/habit_dialogs_test.dart
  git commit -m "feat(ui): name+color habit dialog with swatch picker; dispose controller

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 12: Wire the create flow to the new dialog

**Files:**
- Modify: `lib/ui/habit_list/habit_list_screen.dart`
- Test: `test/ui/habit_list_screen_test.dart`

Create now passes the chosen color.

- [ ] **Step 1: Update the FAB handler**

  In `lib/ui/habit_list/habit_list_screen.dart`, replace the `onPressed` body of
  the `add-habit-fab`:

  ```dart
          onPressed: () async {
            final result = await showHabitNameDialog(context);
            if (result != null) {
              await ref
                  .read(habitListViewModelProvider.notifier)
                  .createHabit(result.name, color: result.color);
            }
          },
  ```

- [ ] **Step 2: Add/adjust a create test**

  In `test/ui/habit_list_screen_test.dart`, if an existing "add habit" test taps
  `habit-name-confirm`, it still works (color defaults). Add a coverage test
  that picks a swatch — model it on the existing add-habit test, then before
  confirming:

  ```dart
      final picked = kHabitPalette[1];
      await tester.tap(
        find.byKey(Key('habit-color-${picked.toRadixString(16)}')),
      );
      await tester.pumpAndSettle();
  ```

  and after creating, assert the stored color:

  ```dart
      final rows = await db.habitDao.getHabitsWithDates();
      expect(rows.single.habit.color, kHabitPalette[1]);
  ```

  Add the import `import 'package:habbits/ui/core/habit_colors.dart';` if absent.

- [ ] **Step 3: Run the test + analyzer**

  Run: `flutter test test/ui/habit_list_screen_test.dart && flutter analyze`
  Expected: PASS, no issues.

- [ ] **Step 4: Commit**

  ```bash
  git add lib/ui/habit_list/habit_list_screen.dart test/ui/habit_list_screen_test.dart
  git commit -m "feat(ui): create habit with a chosen color

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 13: Wire the edit flow to the new dialog

**Files:**
- Modify: `lib/ui/habit_detail/habit_detail_screen.dart`
- Test: `test/ui/habit_detail_screen_test.dart`

Edit pre-fills name+color and applies both via `editHabit`.

- [ ] **Step 1: Update the rename action**

  In `lib/ui/habit_detail/habit_detail_screen.dart`, replace the
  `detail-rename` `onPressed` body:

  ```dart
            onPressed: () async {
              final result = await showHabitNameDialog(
                context,
                initialName: summary.habit.name,
                initialColor: summary.habit.color,
                isRename: true,
              );
              if (result != null) {
                await ref
                    .read(habitDetailViewModelProvider(habitId).notifier)
                    .editHabit(result.name, result.color);
              }
            },
  ```

- [ ] **Step 2: Adjust the existing rename screen test**

  In `test/ui/habit_detail_screen_test.dart`, any test that opens the rename
  dialog and taps `habit-name-confirm` still passes (color defaults to the
  habit's existing color via `initialColor`). If a test asserted on `.rename`
  being called, update the expectation to the persisted name via
  `db.habitDao.getHabitsWithDates()`.

- [ ] **Step 3: Run the test + full suite + analyzer**

  Run: `just test && flutter analyze`
  Expected: all 115+ tests pass, no analyzer issues.

- [ ] **Step 4: Commit**

  ```bash
  git add lib/ui/habit_detail/habit_detail_screen.dart test/ui/habit_detail_screen_test.dart
  git commit -m "feat(ui): edit a habit's name and color from the detail screen

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

### Task 14: Promote docs + clear deferred items + archive

**Files:**
- Modify: `architecture/theming.md`
- Modify: `architecture/habit-tracking.md`
- Modify: `planning/deferred.md`
- Modify: `planning/README.md`
- Move: bundle dir `active/` → `archive/`
- Modify: bundle `design.md` + `plan.md` frontmatter

Promote conclusions into the truth-home and close the bundle. Do this after the
PR is approved (the PR number fills `pr:`).

- [ ] **Step 1: Update `architecture/theming.md`**

  Remove both "Known edges" bullets (no dark theme; non-adaptive cells).
  Document: light + dark `ThemeData` factories (`theme.dart`), `MaterialApp`
  `theme`/`darkTheme`/`themeMode`, `ThemeController`/`AppThemeMode` persisted via
  `SettingsRepository._themeKey`, the Settings selector, and
  `inactiveCellColor` compositing over `ColorScheme.surface`. Fix the
  "Invariants" lines that asserted "theme only / no darkTheme".

- [ ] **Step 2: Update `architecture/habit-tracking.md`**

  Note that habit color is now user-chosen from `kHabitPalette` on create and
  editable on the detail screen via `editHabit` → `HabitRepository.setColor`.

- [ ] **Step 3: Clear resolved `deferred.md` items**

  Delete these four bullets: "No dark theme", "Heatmap/day-strip colors not
  dark-surface adaptive", "Color picker in the create/edit dialog", and
  "`TextEditingController` not disposed in `habit_dialogs.dart`".

- [ ] **Step 4: Archive the bundle**

  ```bash
  git mv planning/changes/active/2026-06-15.07-dark-theme-and-color-picker planning/changes/archive/2026-06-15.07-dark-theme-and-color-picker
  ```

  Set `status: shipped` and fill `pr:`/`outcome:` in the bundle's `design.md`,
  `status: shipped` + `pr:` in `plan.md`, and move the README Index line from
  **Active** to **Archived (shipped)**.

- [ ] **Step 5: Commit**

  ```bash
  git add architecture/ planning/
  git commit -m "docs: promote dark-theme-and-color-picker; archive bundle

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

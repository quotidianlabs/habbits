# Russian language support — design

**Date:** 2026-06-14
**Status:** Approved (pending spec review)

## Goal

Add Russian (`ru`) as a fully supported app language alongside English (`en`). The
app follows the device locale by default and offers an in-app override
(System / English / Русский) that persists. All user-facing UI text, plus the
reminder notification body, is localized. Dates render idiomatically per locale.

Non-goals: translating user data (habit names), changing the backup file format,
or adding languages beyond `en`/`ru` (the infrastructure must make a third
language a drop-in ARB file, but none is added now).

## Mechanism

Flutter's official **`gen-l10n`** (ARB → typed `AppLocalizations`):

- `pubspec.yaml`: add `flutter_localizations` (SDK) and `intl`; set
  `flutter: generate: true`.
- `l10n.yaml` at repo root:
  ```yaml
  arb-dir: lib/l10n
  template-arb-file: app_en.arb
  output-localization-file: app_localizations.dart
  nullable-getter: false
  synthetic-package: false
  ```
  Flutter 3.44 removed the synthetic `flutter_gen` package, so
  `synthetic-package: false` generates `app_localizations*.dart` into
  `lib/l10n/`, imported via the relative path `l10n/app_localizations.dart`.
  These generated files are committed (this project commits generated `*.g.dart`).
- ARB files: `lib/l10n/app_en.arb` (template) and `lib/l10n/app_ru.arb`.
- Generated `AppLocalizations` is reached via `AppLocalizations.of(context)`
  (non-nullable getter) in widgets. The reminder body is localized in the
  `ReminderCoordinator` (which has a `BuildContext`) and passed into
  `NotificationService.syncSchedule`, keeping the service free of any l10n
  dependency.

Rationale: compile-time-safe keys, built-in ICU plural/placeholder support
(required for Russian one/few/many), auto-wires `MaterialLocalizations` so
Flutter's own widgets (e.g. time picker used for reminders) localize too. No
third-party dependency.

## Locale selection + persistence

- New enum `AppLocale { system, en, ru }`.
- `LocaleController` — a Riverpod `Notifier<AppLocale>` (matching the existing
  Riverpod-codegen style in `lib/state/`). Reads the persisted value at startup,
  exposes the current `AppLocale`, and writes on change.
- Persistence: **`shared_preferences`** (new dependency), single string key
  `locale` with values `system | en | ru`. Language is device-local UI state and
  is deliberately kept out of the export/import backup, so importing someone's
  data never changes your language.
- `MaterialApp`:
  - `localizationsDelegates: AppLocalizations.localizationsDelegates`
  - `supportedLocales: AppLocalizations.supportedLocales` (`[en, ru]`)
  - `locale: appLocale == system ? null : Locale(appLocale.code)` — `null` lets
    Flutter resolve the device locale, falling back to `en` for anything not
    `ru`.
- `main()` must load `shared_preferences` before `runApp` (it is async). The
  initial `AppLocale` is read there and seeded into the provider via override,
  mirroring how `notificationServiceProvider` is already overridden in
  `lib/main.dart`.

## Settings UI

`lib/ui/settings/settings_screen.dart` gains a `ListTile`:

- Title: localized "Language" / "Язык"; subtitle shows the current selection's
  display name.
- Tap → `SimpleDialog`/`RadioListTile` group with three options:
  **System default · English · Русский** (each option's label is shown in its
  own language: "English", "Русский", and a localized "System default").
- Selecting an option calls `LocaleController.set(...)`, which persists and
  triggers a rebuild; the change is visible immediately (no restart).

## Strings: translated vs not

**Translated** (moved to ARB keys):

- `settings_screen.dart`: "Settings", "Export data" + subtitle, "Import data" +
  subtitle, "Export failed.", "Replace all data?" + body, "Cancel", "Replace",
  "Import failed. Your existing data was not changed.", "Imported N habits", plus
  the new "Language" tile strings.
- `habit_list_screen.dart`: app bar handled by brand (see below), "Settings"
  tooltip, "No habits yet. Tap + to add one.", "Streak: N", percent "N%"/"—",
  "Error: <e>" (label localized, the error value is interpolated).
- `habit_detail_screen.dart`: "Rename" / "Delete" tooltips, "Streak: N",
  "30-day: N%", "Reminder".
- `habit_dialogs.dart`: "New habit", "Rename habit", "Name" label, "Cancel",
  "Save", `Delete "<name>"?`, the delete-confirmation body, "Delete".
- `recent_days_list.dart`: the "Today ·" prefix (see Dates).
- Notification body: "Time to check in".

**Not translated:**

- Habit names — user data.
- The brand title **"Habbits"** (app bar title and `MaterialApp.title`) stays as
  the product name in all locales.
- JSON keys and the `app: "habbits"` marker in `domain/backup.dart` — file
  format, must stay stable. The `BackupFormatException` *messages* are localized
  only where surfaced to the user (the settings snackbars already use generic
  localized strings; the raw exception messages remain English diagnostics and
  are not shown verbatim).

## Plurals

ICU `plural` in ARB. Russian needs `one/few/many/other`; English `one/other`.
Applies to:

- `Streak: N` (home card + detail)
- `30-day: N%` — percentage, not a count → no plural; placeholder only.
- `Imported N habits`
- `(N habits)` count inside the "Replace all data?" body.

Example (`app_ru.arb`):
```json
"importedHabits": "{count, plural, one{Импортирована {count} привычка} few{Импортировано {count} привычки} many{Импортировано {count} привычек} other{Импортировано {count} привычки}}"
```

## Dates

- Delete `lib/domain/calendar_labels.dart`. It has **two** consumers:
  `recent_days_list.dart` (weekday + month + day) and `heatmap_grid.dart`
  (`monthAbbr3` for the month-label row). Both move to `intl` `DateFormat`.
  `DayStrip` renders colored cells only — no text, unchanged.
- Rewrite `RecentDaysList._label` to use `intl` `DateFormat` with the active
  locale: e.g. `DateFormat('EEE, MMM d', localeName)` for English and the locale
  resolving to `пн, 13 июн` for Russian (ordering and month forms handled by
  `intl`). The "Today ·" prefix becomes an ARB string with the formatted date as
  a placeholder: `todayPrefix(formattedDate)` → "Today · {date}" / "Сегодня ·
  {date}".
- Rewrite `HeatmapGrid._monthLabels` to format months with
  `DateFormat.MMM(localeName)`; thread `localeName` in from `build`'s context.
- `localeName` comes from `Localizations.localeOf(context).toString()`.

## Notifications (context-free localization)

`NotificationService.syncSchedule` builds reminder bodies, but the service is a
pure plugin boundary and should not depend on l10n. The `ReminderCoordinator`
*is* a widget with a `BuildContext`, so it resolves the string and passes it in:

- `syncSchedule` gains a `required String body` parameter. The coordinator calls
  it with `AppLocalizations.of(context).reminderBody`.
- The notification **title** stays the habit name (user data). The **body**
  "Time to check in" is localized.
- The coordinator additionally `ref.listenManual`s the locale controller and
  re-syncs on change, so already-queued notifications pick up the new language
  (it already re-syncs on habit/lifecycle changes; language becomes one more
  trigger).

## Testing

- **Widget tests:** wrap `pumpWidget`s with `AppLocalizations.localizationsDelegates`
  and `supportedLocales`. Existing tests that assert on English strings keep
  passing under the default/`en` locale. Add one test that forces `ru` and
  asserts a known Russian string renders (e.g. Settings shows "Настройки").
- **LocaleController unit test:** system/en/ru resolution and a persistence
  round-trip using `SharedPreferences.setMockInitialValues`.
- **Plural spot-check:** a widget/unit test asserting Russian plural forms for a
  count of 1, 2, and 5 (one/few/many) on the "Streak"/"Imported" strings.
- Pure-domain tests are unaffected — no strings move into `lib/domain/` (the
  removed `calendar_labels.dart` had no behavior worth a domain test; its job
  moves to `intl`).

## Translation source

Russian copy written to be natural and app-appropriate (not literal), authored
as part of implementation. No external glossary required.

## Risks / notes

- `main()` becomes `async` for prefs load before `runApp` — it already awaits
  `notifications.init()`, so this is additive.
- Forcing `intl` date formatting requires `initializeDateFormatting` is not
  needed for `en`/`ru` in Flutter (the `flutter_localizations` delegate covers
  it), but verify Russian `DateFormat` output during implementation.
- Keep ARB keys stable and descriptive; the `app_en.arb` template drives codegen
  and any missing `ru` key falls back to English (acceptable, but the goal is
  full coverage).

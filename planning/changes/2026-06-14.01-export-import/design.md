---
status: shipped
date: 2026-06-14
slug: export-import
summary: JSON export/import with strict backup validation.
supersedes: null
superseded_by: null
pr: merged to main locally
outcome: JSON export/import (share + file picker) with strict backup validation.
---


# Habbits — JSON export / import

The "data ownership" feature from spec §6: export all habits + completions to a
file the user can save/share, and import a file to restore or migrate to a new
device. Fully local (no backend). One versioned JSON file; importing **replaces**
all current data behind a confirmation.

## 1. File format (versioned JSON)

A single JSON object. Each habit carries its completion dates inline, so there is
no id mapping on export or import:

```json
{
  "app": "habbits",
  "version": 1,
  "exportedAt": "2026-06-14T09:30:00.000Z",
  "habits": [
    {
      "name": "Medicine",
      "color": 4278228616,
      "reminderTime": null,
      "sortOrder": 0,
      "createdAt": "2026-06-01T08:00:00.000",
      "completions": ["2026-06-01", "2026-06-02"]
    }
  ]
}
```

- `app` is the literal `"habbits"`; `version` is `1`.
- `exportedAt` / `createdAt` are ISO-8601 strings (`DateTime.toIso8601String()`).
- `color` is the ARGB int stored on the habit; `reminderTime` is `"HH:mm"` or `null`.
- `completions` is an array of `YYYY-MM-DD` strings (the `completions.local_date`
  values). The completion's own `created_at` is audit-only and is **not** exported;
  it is set to "now" on import.

## 2. Export flow

1. One-shot read of all habits + their completion dates from the DAO.
2. Build a `BackupData` (version 1, `exportedAt` = now, habits with inline
   completions).
3. `encodeBackup` → pretty JSON string.
4. Write a temp file `habbits-backup-YYYY-MM-DD.json` (`path_provider`
   temp/documents dir).
5. Open the OS **share sheet** (`share_plus`) so the user saves it to
   Files / Drive / email / anywhere. No storage permission required.

## 3. Import flow (replace, with confirmation)

1. **File picker** (`file_picker`) to choose a `.json` file; read its contents.
2. **Parse + validate** via `decodeBackup` (strict). It must be a Habbits backup
   object with `version == 1`, a `habits` array, each habit having a non-empty
   `name`, integer `color` and `sortOrder`, a parseable `createdAt`, optional
   `reminderTime` (`"HH:mm"` or null), and a `completions` array of valid
   `YYYY-MM-DD` strings. Any violation throws `BackupFormatException` with a
   human-readable message. **Validation happens before any DB write**, so a bad
   file changes nothing.
3. On a valid file, show a strong confirmation: *"This replaces all current habits
   and history with the file's contents. This cannot be undone."*
4. On confirm, `importReplace` runs in a **single transaction**: delete all habits
   (FK cascade clears completions) → insert each habit + its completions
   (completion `created_at` = now). Atomic: a failure leaves the prior data intact.
5. The reactive `watchHabitsWithDates` stream re-emits, so home + detail update
   automatically. A snackbar reports success or the validation error.

## 4. Architecture

```
lib/domain/backup.dart        # NEW (pure Dart): BackupData { version, exportedAt,
                              #   List<BackupHabit> habits }; BackupHabit { name,
                              #   color, reminderTime, sortOrder, createdAt,
                              #   List<String> completions };
                              #   String encodeBackup(BackupData);
                              #   BackupData decodeBackup(String)  // throws
                              #   class BackupFormatException implements Exception
lib/data/habit_dao.dart       # + Future<List<HabitWithDates>> getHabitsWithDates()
                              #     (one-shot read; the .get() form of the existing join)
                              # + Future<void> importReplace(List<BackupHabit> habits)
                              #     (transaction: delete all habits, then insert each
                              #      habit + its completion dates)
lib/services/backup_service.dart  # NEW: glue. buildBackup(dao) -> BackupData;
                                  #   exportAndShare() (encode -> temp file -> share_plus);
                                  #   pickAndDecode() -> BackupData? (file_picker + decode)
lib/ui/settings/settings_screen.dart   # NEW: "Export data" and "Import data" rows;
                                       #   import shows the confirm dialog
lib/ui/habit_list/habit_list_screen.dart  # + a settings IconButton in the AppBar -> Settings
```

**Decomposition.** All format + validation logic lives in the pure
`encodeBackup`/`decodeBackup` (no Flutter, no Drift) and is unit-tested in
isolation. The DAO owns the transactional one-shot read and the wipe-and-load
write, operating on the domain `BackupHabit` type (data depends on domain — fine).
`backup_service` is the thin plugin boundary (path_provider / share_plus /
file_picker). The settings screen composes service calls + the confirm dialog.

`BackupHabit` is the lingua franca: export maps `HabitWithDates` → `BackupHabit`;
import passes `BackupData.habits` (a `List<BackupHabit>`) to `dao.importReplace`.

## 5. Testing

- **Domain (TDD, pure Dart):**
  - encode → decode **round-trip** equality (a `BackupData` survives a string trip).
  - `decodeBackup` **rejects** with `BackupFormatException`: non-JSON text, a JSON
    array (not object), missing/empty `habits`-less object, `version != 1`, a habit
    missing `name`/`color`, a non-string/`null` `reminderTime`, and a malformed
    `completions` date (`"2026-13-40"`, `"June 1"`).
  - well-formed minimal and multi-habit files decode to the expected model.
- **DAO (in-memory DB):**
  - `getHabitsWithDates` returns all habits with their dates.
  - `importReplace` wipes pre-existing data and loads the new set (habits +
    completions); importing an empty habit list clears everything; it runs in one
    transaction.
- **Headline round-trip test:** seed a DB → `buildBackup` → `encodeBackup` →
  `decodeBackup` → `importReplace` into a fresh DB → assert identical habits
  (name/color/reminderTime/sortOrder) and identical completion-date sets. The
  literal "your data survives export/import" guarantee.
- **Settings screen** widget test: the Export and Import rows render; tapping
  Import surfaces the confirm dialog. The actual `share_plus` / `file_picker` /
  `path_provider` plugin calls are NOT unit-tested (platform boundary) — verified
  manually on device. `backup_service`'s testable seams (buildBackup, decode) are
  covered via the domain + DAO tests.

## 6. Out of scope

CSV (any direction), merge-import (replace only), encryption, selective/partial
export, scheduled/automatic backups, cloud destinations (the user chooses the
destination via the OS share sheet). No schema change.

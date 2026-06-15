# Backup I/O

## Purpose

Export the full database to a JSON file and import it back, rejecting anything
that is not a valid Habbits backup.

## Behavior

- **Export**: the Settings screen calls Export, which reads all habits and
  completions in one shot, encodes them as pretty JSON, writes a temp file named
  `habbits-backup-YYYY-MM-DD.json`, and opens the OS share sheet so the user
  can save it to Files, Drive, email, or anywhere else. No storage permission is
  required.
- **Import**: the Settings screen calls Import, which opens a file picker. If
  the user picks a file it is read and strictly validated by `decodeBackup`; any
  violation throws `BackupFormatException` with a user-facing message and no DB
  write occurs. On a valid file the screen shows a confirmation dialog ("Replace
  all data?"). On confirm, `SettingsViewModel.applyImport` calls
  `HabitRepository.importReplace`, which delegates to `HabitDao.importReplace`;
  that method runs in a single Drift transaction: it deletes every completion and
  every habit, then inserts all habits and their completions from the backup.
  Import is **replace-all** — no merge.
- If the user cancels the file picker `pickAndDecode` returns null and the
  screen takes no action.
- After a successful import the reactive `watchHabits()` stream re-emits and
  home + detail screens update automatically.

## Code map

- `lib/domain/backup_codec.dart:10` — `encodeBackup(BackupData) → String`: pure
  function; serializes to pretty JSON; no Drift or Flutter imports
- `lib/domain/backup_codec.dart:32` — `decodeBackup(String) → BackupData`:
  pure strict parser; throws `BackupFormatException` on any violation; never
  returns a partial result
- `lib/domain/backup_codec.dart:131` — `buildBackup(List<HabitWithDates>, DateTime) → BackupData`:
  pure function; maps DAO rows to `BackupData`
- `lib/domain/models/backup_data.dart:2` — `BackupHabit`: per-habit serialized
  shape (name, color, reminderTime, sortOrder, createdAt, completions)
- `lib/domain/models/backup_data.dart:20` — `BackupData`: root document model
  (version, exportedAt, habits)
- `lib/domain/models/backup_data.dart:32` — `BackupFormatException`: thrown by
  `decodeBackup`; `message` is user-facing
- `lib/data/repositories/backup_repository.dart:16` — `BackupRepository`:
  bridges the codec to file I/O and the OS share sheet / file picker; handles
  the export read (`getHabits`) and the file pick + decode; does NOT perform the
  replace-all write
- `lib/data/repositories/backup_repository.dart:21` — `exportAndShare()`:
  encodes → writes temp file → `SharePlus.instance.share`
- `lib/data/repositories/backup_repository.dart:34` — `pickAndDecode()`:
  `FilePicker` → reads file → `decodeBackup`; returns null on cancel
- `lib/data/repositories/habit_repository.dart:28` — `HabitRepository.importReplace()`:
  thin pass-through to `HabitDao.importReplace`; called by `SettingsViewModel.applyImport`
- `lib/data/services/database/habit_dao.dart:121` — `HabitDao.importReplace()`:
  the transactional replace-all — `DELETE completions` → `DELETE habits` →
  insert each habit then its completions

## Invariants

- `decodeBackup` validates and throws `BackupFormatException` on the first violation; it never returns a partial result:
  - **Document shape:** parseable JSON; root is a `Map`; `app == 'habbits'`; `version` is int `1`; `exportedAt` parses as a `DateTime`; `habits` is a `List`.
  - **Per-habit fields:** `name` (non-empty string), `color` (int), `sortOrder` (int), `reminderTime` (string or absent), `createdAt` (parseable datetime), `completions` (list of ISO `YYYY-MM-DD` calendar-valid date strings).
- The codec (`backup_codec.dart`) has no Drift or Flutter imports — it is pure Dart and is unit-testable in isolation.
- Validation completes entirely before any DB write; a bad file leaves existing data untouched.
- `HabitDao.importReplace` runs in a single Drift transaction: `DELETE completions` → `DELETE habits` → insert each habit then its completions. A mid-import failure leaves the database in its prior state.
- `buildBackup` sorts completion dates ascending, producing a stable diff across identical backups.
- Imported completions receive a fresh `created_at` timestamp (`DateTime.now()`); the field is audit-only and is not exported.

## Known edges

- `backup_repository.dart`'s `SharePlus.instance.share` passes no `sharePositionOrigin`, which crashes on iPad — deferred until iPad is a target.

## History

Defined by: [2026-06-14.01-export-import](../planning/changes/archive/2026-06-14.01-export-import/design.md)

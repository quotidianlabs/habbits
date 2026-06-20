---
status: shipped
date: 2026-06-20
slug: localize-share-subject
summary: Localize the backup share-sheet subject, and rename the inverted backup test files.
supersedes: null
superseded_by: null
pr: null
outcome: |
  backupShareSubject ARB key (en/ru) threaded through Settings -> view model ->
  exportAndShare; backup test files renamed to match contents. Closes the
  disputed share-subject item + the backup test-naming deferred item. +1 test
  (148 total), lint clean.
---

# Change: Localize backup share subject + rename backup tests

**Lane:** lightweight — two small, mechanical changes bundled as audit loose-ends.

## Goal

1. **Share subject i18n** (audit, disputed): `backup_repository.dart` passes a
   hard-coded `subject: 'Habbits backup'` to the OS share sheet, so Russian-locale
   users get an English subject when routing a backup to mail/messaging.
2. **Backup test-file naming** (deferred): `backup_test.dart` holds the pure-codec
   tests while `backup_codec_test.dart` holds the DB-backed `buildBackup`/import
   tests — the names are inverted (confirmed in PR #13).

## Approach

1. Add a `backupShareSubject` ARB key (en/ru) and thread it from the Settings
   screen → `SettingsViewModel.export(subject)` → `exportAndShare(subject:)`,
   the same way `reminderBody` is resolved in the view and passed to the service
   (the repository/data layer has no `BuildContext`).
2. Rename to match contents: the pure-codec file becomes `backup_codec_test.dart`;
   the DB-backed file becomes `backup_db_test.dart`.

## Files

- `lib/l10n/app_en.arb`, `app_ru.arb` (+ generated) — `backupShareSubject`.
- `lib/data/repositories/backup_repository.dart` — `exportAndShare({required String subject})`.
- `lib/ui/settings/settings_view_model.dart` — `export(String subject)`.
- `lib/ui/settings/settings_screen.dart` — resolve `l10n.backupShareSubject`, pass it.
- `test/l10n/share_subject_test.dart` (new) — asserts en/ru subject strings.
- rename `test/domain/backup_test.dart` → `backup_codec_test.dart`,
  `backup_codec_test.dart` → `backup_db_test.dart`.

## Verification

- [ ] Failing test first — `share_subject_test` asserts the ru subject before the key exists.
- [ ] Add the key + thread it; rename the test files.
- [ ] `just test` green; `just lint` clean.

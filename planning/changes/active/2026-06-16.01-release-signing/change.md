---
status: draft
date: 2026-06-16
slug: release-signing
supersedes: null
superseded_by: null
pr: null
outcome: null
---

# Change: Android release signing for Google Play

**Lane:** lightweight — one tracked file (`android/app/build.gradle.kts`); the
keystore and `key.properties` are local secrets, never committed.

## Goal

Make `flutter build appbundle --release` produce a Play-uploadable, upload-key-
signed AAB instead of a debug-signed artifact, so the app can be submitted to
Google Play.

## Approach

Read the signing material from `android/key.properties` (already covered by
`android/.gitignore`, alongside `**/*.jks` / `**/*.keystore`). `build.gradle.kts`
loads it into a `signingConfigs.release`, and the `release` build type uses that
config **when the keystore is present**, falling back to the debug key when it
is absent (CI, fresh clones) so `flutter run --release` and local builds keep
working without secrets.

The upload keystore is a **local, uncommitted** artifact:
- `android/upload-keystore.jks` — RSA 2048, alias `upload`, 10000-day validity,
  `CN=Habbits, O=quotidianlabs, C=US`.
- SHA-256 fingerprint
  `E2:7B:33:71:B6:45:68:A3:E1:B5:75:24:F3:49:4A:50:7E:62:F3:0F:25:F8:2D:A8:24:9E:20:7E:92:98:88:1A`.
- The keystore + password live only on the build machine and must be backed up;
  losing them means re-enrolling an upload key via Play support (Play App
  Signing holds the actual app signing key, so this is recoverable but annoying).

## Files

- `android/app/build.gradle.kts` — load `key.properties`; add
  `signingConfigs.release`; release build type uses it with a debug fallback.
- `android/key.properties` — **local, gitignored** (storePassword/keyPassword/
  keyAlias/storeFile).
- `android/upload-keystore.jks` — **local, gitignored** upload keystore.

## Verification

- [x] Keystore generated; `key.properties` written; both confirmed gitignored
  (`git check-ignore`).
- [x] `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab` (60.2 MB).
- [x] AAB signer cert SHA-256 matches the upload key (not the debug key),
  verified with `keytool -printcert -jarfile`.
- [x] `flutter analyze` — clean.

## Follow-ups (addressed in this bundle)

- **`targetSdk` pinned** — `compileSdk` and `targetSdk` set to 36 explicitly in
  `build.gradle.kts` (was inheriting `flutter.*`); rebuilt the AAB to confirm it
  compiles against API 36.
- **Exact alarms — no change needed** — `NotificationService.syncSchedule` uses
  `AndroidScheduleMode.inexactAllowWhileIdle`, so no
  `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` permission or Play declaration is
  required. Documented in [`docs/release.md`](../../../../docs/release.md).
- **`versionCode` bump** — documented as a per-upload requirement in
  `docs/release.md` (the full release runbook); `1.0.0+1` stands for the first
  upload.

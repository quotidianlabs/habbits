# Releasing to Google Play

How to cut an Android release build (`.aab`) for the Play Console.

## Prerequisites

- The Android toolchain on PATH (see the `android-integration-test-setup`
  session memory for the local setup):

  ```bash
  export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
  export JAVA_HOME=/opt/homebrew/opt/openjdk@17
  export PATH="/opt/homebrew/bin:$JAVA_HOME/bin:$PATH"
  ```

- The **upload keystore** and `android/key.properties` present on the build
  machine. Both are gitignored (`android/.gitignore`). Without them the release
  build falls back to debug signing (fine for local runs, **rejected by Play**).

## Signing

Release signing is wired in `android/app/build.gradle.kts`: it loads
`android/key.properties` into `signingConfigs.release` and uses it for the
`release` build type when present, else falls back to the debug key.

`android/key.properties` format:

```properties
storePassword=<store password>
keyPassword=<key password>
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

> **Back up the keystore and its password offline.** Play App Signing holds the
> real app signing key, so a lost *upload* key is recoverable via Play support,
> but it's avoidable pain. To regenerate an upload key:
>
> ```bash
> keytool -genkeypair -v -keystore upload-keystore.jks \
>   -alias upload -keyalg RSA -keysize 2048 -validity 10000
> ```

## Versioning

`pubspec.yaml` → `version: x.y.z+N`:

- `x.y.z` → `versionName` (the human version shown to users).
- `+N` → `versionCode` (an integer Play uses for ordering).

**`versionCode` must strictly increase on every upload to the Play Console.**
Bump `+N` (and `x.y.z` when appropriate) before each release build.

## Build the App Bundle

```bash
flutter build appbundle --release
# -> build/app/outputs/bundle/release/app-release.aab
```

Play requires an `.aab`, not an `.apk`. (`flutter build apk` is only for
sideloading/testing.)

Verify it was signed with the upload key (not debug) — the SHA-256 should match
your keystore:

```bash
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

## Target API

`compileSdk` and `targetSdk` are pinned to **36** in `build.gradle.kts` to meet
Play's target-API requirement explicitly. Bump both together when targeting a
newer Android release (`compileSdk` must be ≥ `targetSdk`, and the matching
`platforms;android-<N>` + `build-tools;<N>` SDK packages must be installed).

## Notifications

Reminders schedule with `AndroidScheduleMode.inexactAllowWhileIdle`
(`lib/data/services/notification_service.dart`), so the app needs **no**
`SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` permission and no Play exact-alarm
declaration. Keep it inexact unless a feature genuinely needs to-the-minute
delivery (which would then require a Play policy declaration).

## Then

Upload the `.aab` in the Play Console, fill the store listing, privacy policy,
and data-safety / content-rating forms, and roll out.

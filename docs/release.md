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

# Sideload APK via GitHub Releases

A parallel distribution channel to the Play `.aab` above: pushing a `v*` tag
builds a signed **universal** APK and publishes a GitHub Release with it
attached. Driven by [`.github/workflows/release.yml`](../.github/workflows/release.yml).

> **Distinct signing identity.** This APK is signed with the **upload key
> directly**, whereas Play App Signing re-signs Play installs with the real app
> key. The two are therefore signed differently and **cannot be upgraded over
> each other**. Expected for a sideload channel — just don't tell users to
> "update from Play over the sideload build."

## One-time setup: repo secrets

Encode the existing upload keystore (the same `.jks` from the signing section
above) and add four repository secrets under
**Settings → Secrets and variables → Actions**:

```bash
base64 -i /absolute/path/to/upload-keystore.jks | pbcopy   # -> ANDROID_KEYSTORE_BASE64
```

| Secret | Value |
|--------|-------|
| `ANDROID_KEYSTORE_BASE64` | base64 of `upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | the store password |
| `ANDROID_KEY_PASSWORD` | the key password (often same as store) |
| `ANDROID_KEY_ALIAS` | `upload` |

The workflow fails loudly if `ANDROID_KEYSTORE_BASE64` is missing — it will
never silently fall back to debug-signing.

## Cutting a release

1. Bump `pubspec.yaml` `version: X.Y.Z+N` and merge to `main`.
2. (Optional) Write user-facing notes to `planning/releases/X.Y.Z.md`. If
   present, they become the release body; GitHub's auto-generated "What's
   Changed" PR list is appended either way.
3. Tag and push — the tag `vX.Y.Z` **must** match `pubspec.yaml` `X.Y.Z`:

   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

4. The workflow builds `habbits-vX.Y.Z.apk` and publishes the GitHub Release.

Verify the published asset is upload-signed (not debug):

```bash
apksigner verify --print-certs habbits-vX.Y.Z.apk   # DN must NOT be CN=Android Debug
```

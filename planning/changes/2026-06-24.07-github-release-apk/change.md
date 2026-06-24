---
status: shipped
date: 2026-06-24
slug: github-release-apk
summary: Publish a signed universal release APK to GitHub Releases on every `v*` tag.
supersedes: null
superseded_by: null
pr: 30
outcome: Added `.github/workflows/release.yml` (v* tag → signed universal APK → published GitHub Release) plus docs and the `planning/releases/` notes convention. Signing secrets + first `v1.0.0` tag are a manual post-merge step.
---

# Change: Signed APK on GitHub Releases

**Lane:** lightweight — one new CI workflow + a docs section. (Borderline Full,
since it adds a new file; kept lightweight by explicit decision — no app code,
no public-API change, no Gradle change.)

## Goal

Give Habbits a sideload distribution channel: pushing a `v*` git tag builds a
signed **universal** release APK and **auto-publishes** a GitHub Release with the
APK attached and notes sourced from `planning/releases/<semver>.md`. This is an
additive, parallel channel to the Play `.aab` flow in
[`docs/release.md`](../../../docs/release.md) — that flow is untouched.

## Approach

A new `.github/workflows/release.yml`, triggered on `push: { tags: ['v*'] }`
with `permissions: { contents: write }`:

1. **checkout** + `subosito/flutter-action` (3.44.2 / stable / cache) — mirrors
   `ci.yml`.
2. **Reconstruct signing** from secrets: decode `ANDROID_KEYSTORE_BASE64` →
   `android/upload-keystore.jks`; write `android/key.properties` from the
   secrets. The existing `android/app/build.gradle.kts` `hasReleaseKeystore`
   logic picks it up automatically — **no Gradle change** (proven locally: a
   `flutter build apk --release` with `key.properties` present produced an APK
   signed by the upload key, DN `CN=Unknown…`, not the debug fallback).
3. **Signing guard**: fail loudly if the decoded keystore is empty/missing, so a
   release can never silently fall back to debug-signing.
4. **Version guard**: assert the tag (`v1.0.0`) matches `pubspec.yaml`
   `version:` (`1.0.0+N`) — prevents mislabeled releases.
5. `flutter pub get` → `flutter build apk --release` →
   `build/app/outputs/flutter-apk/app-release.apk`.
6. Rename to `habbits-<tag>.apk` for a clean asset name.
7. **Resolve notes**: tag `vX.Y.Z` → `planning/releases/X.Y.Z.md`. If present,
   pass as `body_path`; always set `generate_release_notes: true` so GitHub's
   "What's Changed" PR list is appended. Absent file → auto-notes only.
8. `softprops/action-gh-release` → **published** release (`draft: false`) with
   the APK attached.

### Signing key

Reuses the **existing upload keystore** (`~/upload-keystore.jks`), base64-encoded
into a secret. Note: this APK channel is signed with the upload key directly, so
it is a **distinct signing identity** from Play-distributed installs (Play App
Signing re-signs) — the two cannot upgrade over each other. Expected and fine
for a sideload channel; documented in `docs/release.md`.

### One-time setup (manual, not in this change)

Add four GitHub Actions secrets:

- `ANDROID_KEYSTORE_BASE64` — `base64 -i ~/upload-keystore.jks`
- `ANDROID_KEYSTORE_PASSWORD` (storePassword)
- `ANDROID_KEY_PASSWORD` (keyPassword)
- `ANDROID_KEY_ALIAS` (`upload`)

## Files

- `.github/workflows/release.yml` — new release workflow (tag → signed APK →
  published GitHub Release).
- `docs/release.md` — add a "GitHub Release APK" section: tag flow, the four
  secrets, the `planning/releases/<semver>.md` notes convention, and the
  distinct-signing-identity caveat.
- `planning/releases/` — home for per-release notes files (created on first use;
  convention already declared in `planning/README.md`).

## Verification

Workflows can't be unit-tested; verification is the first real release.

- [x] Local proof: `flutter build apk --release` with `key.properties` present
      → APK signed by upload key (SHA-256 `47ff808c…`), not debug.
- [ ] Add the four secrets to the GitHub repo.
- [ ] Push the first tag: `git tag v1.0.0 && git push --tags`.
- [ ] Workflow succeeds; a published Release `v1.0.0` appears with
      `habbits-v1.0.0.apk` attached.
- [ ] Download the asset; `apksigner verify --print-certs habbits-v1.0.0.apk`
      shows the upload-key cert (SHA-256 `47ff808c…`), not `CN=Android Debug`.
- [ ] APK installs on a device.
- [ ] Negative check: a tag mismatching `pubspec.yaml` version fails the
      version guard (not a silent mislabel).

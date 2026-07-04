# RuStore Publishing + Release-Notes Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give habbits RuStore publishing from CI (guarded), make curated stable-tag release notes publish verbatim, add a GitHub Pages privacy site, and produce a standalone nooka-vs-habbits audit.

**Architecture:** Mirror the sibling app `nooka` (at `../tasks`, package `io.github.quotidianlabs.nooka`), which already ships this tooling. Adapt all content for habbits: a habit tracker with **local-only data** (JSON export/import; no Google Drive backup). Everything ships **inert** until the maintainer completes the manual RuStore account setup and adds the `RUSTORE_CREDENTIALS` secret.

**Tech Stack:** GitHub Actions, Gradle (Kotlin DSL), `ru.cian.rustore-publish-gradle-plugin` `0.5.5`, static HTML on GitHub Pages, Flutter 3.44.2.

## Global Constraints

- **This is config/CI/docs work, not Dart logic** — there are no unit tests to write. Each task's "verification" is running the relevant validator (Gradle, a YAML parse, `just lint`, link inspection) and confirming its output, then committing.
- Package name is `io.github.quotidianlabs.habbits` (never `nooka`). Org is `quotidianlabs`.
- Release APK asset name is `habbits-${GITHUB_REF_NAME}.apk` (habbits' existing rename step) — never `nooka-...`.
- Privacy URL is `https://quotidianlabs.github.io/habbits/privacy`.
- RuStore plugin version is exactly `0.5.5`. Developer contact email is `me@shiriev.ru`.
- RuStore upload MUST stay guarded: it runs only when `RUSTORE_CREDENTIALS` is non-empty AND the tag is not a pre-release. Merging this plan must not be able to attempt an upload.
- habbits has **no Google Drive backup** — omit every Drive-related sentence when adapting nooka's privacy page and runbook.
- Work happens on the existing `rustore-publishing` branch. Finish via PR (never local-merge), per the maintainer's workflow.
- Commit after each task. Run `just lint` before any commit that touches Dart/format-covered files (none here, but keep `dart format` clean on new files).

---

### Task 1: Publish curated stable-tag notes verbatim

**Files:**
- Modify: `.github/workflows/release.yml` (the "Resolve release metadata" step and the "Publish GitHub Release" step)

**Interfaces:**
- Produces: a `generate_notes` output on the `meta` step (`"true"`/`"false"` string), consumed by the Publish step in this same task.

The existing "Require curated release notes (stable tags)" step already aborts a stable tag with no `planning/releases/<tag>.md`. This task makes the publish step actually use those notes verbatim instead of always appending GitHub's auto "What's Changed".

- [ ] **Step 1: Update the "Resolve release metadata" step**

Replace the current step (habbits `release.yml` ~lines 99-114) with this. The comment is updated to match nooka's intent, and the body now emits `generate_notes`:

```yaml
      # Notes: tag -> planning/releases/<tag>.md. When present it is the release
      # body verbatim (generate_notes=false, no auto "What's Changed" appended);
      # the guard above makes it mandatory for stable tags, so the generated-notes
      # fallback only ever fires for a pre-release without a curated file.
      # Pre-release: any tag with a "-suffix" (e.g. 1.0.0-beta.1) is flagged so
      # GitHub does not mark it "Latest".
      - name: Resolve release metadata
        id: meta
        run: |
          set -euo pipefail
          notes="planning/releases/${GITHUB_REF_NAME}.md"
          if [ -f "$notes" ]; then
            echo "body_path=$notes" >> "$GITHUB_OUTPUT"
            echo "generate_notes=false" >> "$GITHUB_OUTPUT"
          else
            echo "generate_notes=true" >> "$GITHUB_OUTPUT"
          fi
          if [[ "$GITHUB_REF_NAME" == *-* ]]; then
            echo "prerelease=true" >> "$GITHUB_OUTPUT"
          else
            echo "prerelease=false" >> "$GITHUB_OUTPUT"
          fi
```

- [ ] **Step 2: Update the "Publish GitHub Release" step**

In the same file, change the hardcoded `generate_release_notes: true` to read the new output. The step becomes:

```yaml
      - name: Publish GitHub Release
        uses: softprops/action-gh-release@v3
        with:
          files: build/app/outputs/flutter-apk/habbits-${{ github.ref_name }}.apk
          body_path: ${{ steps.meta.outputs.body_path }}
          prerelease: ${{ steps.meta.outputs.prerelease }}
          generate_release_notes: ${{ steps.meta.outputs.generate_notes }}
          draft: false
```

- [ ] **Step 3: Verify the workflow is still valid YAML**

Run:
```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml')); print('ok')"
```
Expected: `ok`

- [ ] **Step 4: Verify the logic by reading**

Run:
```bash
grep -n "generate_notes\|generate_release_notes" .github/workflows/release.yml
```
Expected: three hits — `generate_notes=false` (curated path), `generate_notes=true` (fallback path), and `generate_release_notes: ${{ steps.meta.outputs.generate_notes }}` in the publish step. Confirm there is NO remaining `generate_release_notes: true`.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci(release): use curated stable-tag notes verbatim

Emit a generate_notes output from the meta step and pass it to
softprops/action-gh-release, so a stable tag with planning/releases/<tag>.md
publishes those notes without GitHub appending auto 'What's Changed'.
Pre-release tags keep the generated-notes fallback.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: RuStore Gradle wiring + RU notes file

**Files:**
- Modify: `android/settings.gradle.kts` (add plugin to the `plugins {}` block)
- Modify: `android/app/build.gradle.kts` (apply plugin; append `rustorePublish {}` block)
- Create: `android/app/rustore-release-notes-ru.txt`
- Modify: `android/.gitignore` (ignore the runtime credentials file)

**Interfaces:**
- Produces: a Gradle task `:app:publishRustoreRelease` (from the plugin) that later CI (Task 3) invokes. Configuration reads `rustore-credentials.json` at `android/` root at run time only.

- [ ] **Step 1: Declare the plugin in `settings.gradle.kts`**

In `android/settings.gradle.kts`, add a line to the `plugins { }` block, right after the Kotlin plugin line:

```kotlin
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
    id("ru.cian.rustore-publish-gradle-plugin") version "0.5.5" apply false
```

- [ ] **Step 2: Apply the plugin in `app/build.gradle.kts`**

In `android/app/build.gradle.kts`, add the plugin id to the `plugins { }` block after the Flutter Gradle Plugin line:

```kotlin
plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("ru.cian.rustore-publish-gradle-plugin")
}
```

- [ ] **Step 3: Add the `rustorePublish` block at the end of `app/build.gradle.kts`**

Append after the existing `dependencies { }` block (end of file). Note habbits keeps its `dependencies` block for core-library desugaring; the RuStore block is independent and goes after it:

```kotlin
// RuStore publishing (cianru plugin). Inert unless `publishRustoreRelease` is
// invoked with a credentials file present — see .github/workflows/release.yml.
rustorePublish {
    instances {
        create("release") {
            credentialsPath = "$rootDir/rustore-credentials.json"
            buildFormat = ru.cian.rustore.publish.BuildFormat.APK
            // Flutter writes the universal APK here (repo-root/build/...).
            buildFile = "$rootDir/../build/app/outputs/flutter-apk/app-release.apk"
            publishType = ru.cian.rustore.publish.PublishType.INSTANTLY
            developerContacts = ru.cian.rustore.publish.DeveloperContacts(
                email = "me@shiriev.ru",
                website = "https://github.com/quotidianlabs/habbits",
                vkCommunity = null,
            )
            releaseNotes = listOf(
                ru.cian.rustore.publish.ReleaseNote(
                    lang = "ru-RU",
                    filePath = "$rootDir/app/rustore-release-notes-ru.txt",
                ),
            )
        }
    }
}
```

- [ ] **Step 4: Create the RU release-notes file**

Create `android/app/rustore-release-notes-ru.txt` with exactly one line (matches nooka's default):

```
Исправления ошибок и улучшения стабильности.
```

- [ ] **Step 5: Ignore the runtime credentials file**

Read `android/.gitignore`, then add this line under the keystore section (near the `**/*.jks` line):

```
rustore-credentials.json
```

Verify it is not already present and is now ignored:
```bash
grep -n "rustore-credentials.json" android/.gitignore
```
Expected: one hit.

- [ ] **Step 6: Verify the plugin resolves and the task exists**

This needs the local Android toolchain (see `docs/development.md`: `ANDROID_HOME`, `JAVA_HOME`, and `android/local.properties` with `flutter.sdk`). Run:

```bash
cd android && ./gradlew tasks --console=plain | grep -i rustore; cd ..
```
Expected: a line listing `publishRustoreRelease` (the plugin's task). If Gradle fails to *configure*, the `rustorePublish` block or plugin id is wrong — fix before committing. No network upload happens; the task only runs when explicitly invoked with credentials.

- [ ] **Step 7: Commit**

```bash
git add android/settings.gradle.kts android/app/build.gradle.kts android/app/rustore-release-notes-ru.txt android/.gitignore
git commit -m "build(android): wire ru.cian rustore-publish plugin

Add the RuStore publishing plugin (0.5.5) and an inert rustorePublish
'release' instance (APK, INSTANTLY, ru-RU notes). Produces the
publishRustoreRelease task consumed by the release workflow; no-op unless
invoked with android/rustore-credentials.json present (gitignored).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Guarded RuStore upload in the release workflow

**Files:**
- Modify: `.github/workflows/release.yml` (append two steps after "Publish GitHub Release")

**Interfaces:**
- Consumes: `steps.meta.outputs.prerelease` (from Task 1's meta step) and the `:app:publishRustoreRelease` task (from Task 2).
- Consumes: the renamed asset `build/app/outputs/flutter-apk/habbits-${GITHUB_REF_NAME}.apk` (from the existing "Rename APK" step).

- [ ] **Step 1: Append the guarded RuStore steps**

Add to the end of the `steps:` list in `.github/workflows/release.yml`, after the "Publish GitHub Release" step:

```yaml
      # Upload to RuStore only on stable tags (RuStore has no closed-test track)
      # and only when credentials are configured — so tags still cut a GitHub
      # Release before the RuStore account exists.
      - name: Check RuStore credentials
        id: rustore
        env:
          RS: ${{ secrets.RUSTORE_CREDENTIALS }}
        run: |
          set -euo pipefail
          if [ -n "${RS:-}" ] && [ "${{ steps.meta.outputs.prerelease }}" = "false" ]; then
            echo "enabled=true" >> "$GITHUB_OUTPUT"
          else
            echo "::notice::RuStore upload skipped (no credentials or prerelease tag)."
            echo "enabled=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Upload APK to RuStore
        if: steps.rustore.outputs.enabled == 'true'
        working-directory: android
        env:
          RUSTORE_CREDENTIALS: ${{ secrets.RUSTORE_CREDENTIALS }}
        run: |
          set -euo pipefail
          printf '%s' "$RUSTORE_CREDENTIALS" > rustore-credentials.json
          ./gradlew :app:publishRustoreRelease \
            --buildFile="$GITHUB_WORKSPACE/build/app/outputs/flutter-apk/habbits-${GITHUB_REF_NAME}.apk"
```

- [ ] **Step 2: Verify valid YAML**

Run:
```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml')); print('ok')"
```
Expected: `ok`

- [ ] **Step 3: Verify the guard by reading**

Run:
```bash
grep -n "enabled=true\|enabled=false\|if: steps.rustore\|habbits-\${GITHUB_REF_NAME}.apk" .github/workflows/release.yml
```
Expected: `enabled=true` is emitted only inside the `[ -n "${RS:-}" ] && prerelease == false` branch; the upload step is gated `if: steps.rustore.outputs.enabled == 'true'`; and the `--buildFile` path uses `habbits-...apk` (not `nooka-`). Confirm: with no secret, `RS` is empty → `enabled=false` → upload step skipped. Merging cannot attempt an upload.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci(release): guarded RuStore upload on stable tags

Add Check RuStore credentials + Upload APK to RuStore steps. Runs
publishRustoreRelease only when RUSTORE_CREDENTIALS is set and the tag is
not a prerelease; otherwise logs a notice and skips, so tags still cut a
GitHub Release before the RuStore account exists.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Privacy site on GitHub Pages

**Files:**
- Create: `.github/workflows/pages.yml`
- Create: `site/index.html`
- Create: `site/privacy/index.html`

**Interfaces:**
- Produces: a static site deployed to `https://quotidianlabs.github.io/habbits/`, with the privacy policy at `/privacy` — the URL RuStore's listing requires (Task 5's runbook points there).

- [ ] **Step 1: Create the Pages workflow**

Create `.github/workflows/pages.yml` (verbatim from nooka — no adaptation needed):

```yaml
name: pages

on:
  push:
    branches: [main]
    paths:
      - 'site/**'
      - '.github/workflows/pages.yml'
  workflow_dispatch:

# Least-privilege permissions required by the Pages deploy actions.
permissions:
  contents: read
  pages: write
  id-token: write

# One Pages deployment at a time; don't cancel an in-progress deploy.
concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - uses: actions/checkout@v5
      - uses: actions/configure-pages@v5
      # Static HTML — upload site/ as-is, no build step.
      - uses: actions/upload-pages-artifact@v3
        with:
          path: site
      - id: deployment
        uses: actions/deploy-pages@v5
```

- [ ] **Step 2: Create the landing page**

Create `site/index.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Habbits</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 42rem; margin: 3rem auto;
           padding: 0 1rem; line-height: 1.6; }
    a { color: #2563eb; }
  </style>
</head>
<body>
  <h1>Habbits</h1>
  <p>A local-first habit tracker for iOS and Android.</p>
  <p><a href="privacy/">Privacy policy</a></p>
</body>
</html>
```

- [ ] **Step 3: Create the privacy policy page**

Create `site/privacy/index.html`. This is adapted from nooka's, trimmed for habbits' local-only reality: **no Google Drive section**, habit-tracker wording, JSON export/import kept:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Habbits — Privacy Policy</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 42rem; margin: 3rem auto;
           padding: 0 1rem; line-height: 1.6; }
    h1, h2 { line-height: 1.25; }
    code { background: #f3f4f6; padding: 0 .25rem; border-radius: .25rem; }
  </style>
</head>
<body>
  <h1>Habbits — Privacy Policy</h1>
  <p><em>Last updated: 2026-07-04</em></p>

  <p>Habbits is a local-first habit tracker. Your data lives on your device.
    The developer runs no server and operates no backend: there is no account
    system, no analytics, no advertising, and no tracking.</p>

  <h2>Data stored on your device</h2>
  <p>Your habits and completions are stored locally on your device in an SQLite
    database. Aside from features you control (see below) and your device's own
    operating-system backup (Android Auto Backup or iOS device backup, which
    copy app data to your own cloud account), this data stays on your device.</p>

  <h2>Optional file export and import</h2>
  <p>You can export your data to a JSON file via the system share sheet, and
    import it again later. Where that file goes is entirely your choice; Habbits
    does not upload it anywhere.</p>

  <h2>Data sharing</h2>
  <p>The developer does not collect, sell, or share any of your data with third
    parties.</p>

  <h2>Deleting your data</h2>
  <p>Uninstalling the app removes its on-device data (a copy may remain in your
    device's own operating-system backup until that backup is cleared).</p>

  <h2>Children</h2>
  <p>Habbits is a general-audience productivity app and is not directed at
    children.</p>

  <h2>Contact</h2>
  <p>Questions about this policy: <a href="mailto:me@shiriev.ru">me@shiriev.ru</a>.</p>
</body>
</html>
```

- [ ] **Step 4: Verify the workflow parses and links resolve**

Run:
```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/pages.yml')); print('yaml ok')"
python3 -c "import pathlib,html.parser
for p in ['site/index.html','site/privacy/index.html']:
    html.parser.HTMLParser().feed(pathlib.Path(p).read_text()); print(p,'parsed')"
test -f site/privacy/index.html && echo "privacy link target exists"
```
Expected: `yaml ok`, both files `parsed`, and `privacy link target exists`. Confirm the privacy page contains **no** "Google Drive" text:
```bash
grep -ci "google drive" site/privacy/index.html
```
Expected: `0`

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/pages.yml site/index.html site/privacy/index.html
git commit -m "feat(site): GitHub Pages privacy policy for RuStore

Add a static landing page and privacy policy (served at
quotidianlabs.github.io/habbits/privacy) plus the pages deploy workflow.
Adapted from nooka for habbits' local-only data model (no Google Drive
section). Satisfies RuStore's privacy-policy URL requirement.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: RuStore runbook + README badge + release-doc pointer

**Files:**
- Create: `docs/rustore-release.md`
- Modify: `README.md` (add RuStore badge after the Release badge)
- Modify: `docs/release.md` (add a short RuStore pointer section)

- [ ] **Step 1: Create the runbook**

Create `docs/rustore-release.md` (adapted from nooka: habbits package, habbits privacy URL, no Google Drive caveat):

````markdown
# Publishing Habbits to RuStore

How Habbits reaches RuStore (VK's Russian Android store). The CI half (build +
upload) is automated in
[`.github/workflows/release.yml`](../.github/workflows/release.yml); this doc is
the **manual** half. Steps are ordered by dependency.

## 1. Create and verify the developer account
- Register at the RuStore Console with a **VK ID** (an individual account needs
  nothing more to create). No fee.
- Complete **verification** by uploading a photo of your passport. Monetization
  (self-employed) is not needed — Habbits is free with no ads.

## 2. Create the app
- Create an app with package name **`io.github.quotidianlabs.habbits`** (must
  match the APK; RuStore matches uploads by package name).

## 3. Generate an API key for CI
- In RuStore Console, open the API-keys section and create a key. It yields a
  **`key_id`** and a **`client_secret`**.
- In GitHub → repo **Settings → Secrets and variables → Actions**, add secret
  **`RUSTORE_CREDENTIALS`** with this exact JSON:

  ```json
  { "key_id": "<KEY_ID>", "client_secret": "<CLIENT_SECRET>" }
  ```

## 4. Enable the privacy site (GitHub Pages)
- Repo **Settings → Pages → Source: GitHub Actions**. The `pages` workflow then
  serves the policy at `https://quotidianlabs.github.io/habbits/privacy` — use
  this as the app's privacy-policy URL.

## 5. Complete the store listing (Russian-first)
- 512×512 icon, at least one screenshot, a description (≤4000 chars), and an
  **age rating**. Set the privacy-policy URL from step 4.

## 6. Publish
- Ensure `pubspec.yaml` `+N` is higher than any previous RuStore upload, merge
  to `main`, then push a **stable tag** (e.g. `1.1.0`, matching `pubspec.yaml`).
  CI builds the signed APK and uploads it to RuStore
  (`publishRustoreRelease`, `publishType = INSTANTLY` → submitted to moderation).
- The first upload can also be done **manually** in the Console (upload
  `habbits-<tag>.apk` from the GitHub Release) if you want to establish the app
  before wiring the secret.

## Notes
- **Version code already used** → bump `pubspec.yaml` `+N` and re-tag.
- A tag before the account/secret exists is fine: the RuStore step is skipped
  with a notice and the GitHub Release still ships.
- Habbits stores all data locally (JSON file export/import works everywhere);
  there is no cloud-sync dependency on Google Play Services.
````

- [ ] **Step 2: Add the RuStore badge to the README**

In `README.md`, insert the RuStore badge line immediately after the existing Release badge line (before the CI badge):

```markdown
[![Release](https://img.shields.io/github/v/release/quotidianlabs/habbits)](https://github.com/quotidianlabs/habbits/releases/latest)
[![RuStore](https://img.shields.io/badge/RuStore-Download-0A7CFF)](https://www.rustore.ru/catalog/app/io.github.quotidianlabs.habbits)
[![CI](https://github.com/quotidianlabs/habbits/actions/workflows/ci.yml/badge.svg)](https://github.com/quotidianlabs/habbits/actions/workflows/ci.yml)
```

- [ ] **Step 3: Add a RuStore pointer to `docs/release.md`**

habbits' `docs/release.md` covers the Play `.aab` flow. Append a short section at the end of the file so the RuStore path is discoverable:

```markdown

## RuStore

The stable-tag release workflow also uploads the signed universal APK to
**RuStore** (VK's Russian Android store) via
`ru.cian.rustore-publish-gradle-plugin` (task `publishRustoreRelease`). The
upload is **guarded**: it runs only when the `RUSTORE_CREDENTIALS` secret is set
and the tag is not a pre-release, so tags still cut a GitHub Release otherwise.

Account signup, API-key generation, GitHub Pages privacy policy, and the Russian
store listing are in [`rustore-release.md`](rustore-release.md).
```

- [ ] **Step 4: Verify links and package references**

Run:
```bash
grep -n "io.github.quotidianlabs.habbits" README.md docs/rustore-release.md
grep -rin "nooka" README.md docs/rustore-release.md docs/release.md
```
Expected: the package appears in the README badge and the runbook; the second grep returns **no** hits (no leftover `nooka` references). Confirm `docs/rustore-release.md` links (`release.yml`) resolve relative to `docs/`.

- [ ] **Step 5: Commit**

```bash
git add docs/rustore-release.md README.md docs/release.md
git commit -m "docs: RuStore runbook, README badge, release-doc pointer

Add the manual RuStore setup runbook (account, API key, Pages privacy URL,
listing), a RuStore download badge, and a pointer section in the Play
release doc. Adapted from nooka; no Google Drive caveat.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: nooka-vs-habbits comparison audit

**Files:**
- Create: `planning/nooka-vs-habbits-audit.md`

Loose docs already live in `planning/` (`README.md`, `deferred.md`), so a loose audit file is fine and does not form a planning bundle.

- [ ] **Step 1: Write the audit doc**

Create `planning/nooka-vs-habbits-audit.md`. Fill each row from the facts already gathered (cited by nooka PR number where known). Tag every row **Portable** / **Divergent-by-design** / **Skip** with a one-line recommendation:

```markdown
# nooka vs habbits: cross-app audit

Date: 2026-07-04

Both apps share a lineage and are kept in sync on tooling. This audit compares
`habbits` against its sibling `nooka` (`../tasks`, package
`io.github.quotidianlabs.nooka`) and flags what else could be ported. Rows
closed by the RuStore/release-notes work (see
`docs/superpowers/plans/2026-07-04-rustore-publishing-and-release-notes.md`) are
marked **Done here**.

## CI/CD

| Item | nooka | habbits | Call | Recommendation |
|------|-------|---------|------|----------------|
| Curated stable-tag notes verbatim | yes | **Done here** | Portable | Shipped in this branch |
| Guarded RuStore upload | yes (#41) | **Done here** | Portable | Shipped in this branch |
| GitHub Pages privacy site (`pages.yml` + `site/`) | yes | **Done here** | Portable | Shipped in this branch |
| Docs/planning-only CI skip (`paths-ignore` `**/*.md`, `planning/**`, `architecture/**`, `docs/**`) | yes (#37) | no | Portable | Small, high-value; add `paths-ignore` to `ci.yml`. Note the caveat nooka documents: safe only while `main` has no required checks — else add an always-running gate job. |

## Features

| Item | nooka | habbits | Call | Recommendation |
|------|-------|---------|------|----------------|
| Google Drive cloud backup | yes (#32, #33) | no (local JSON only) | Portable | Largest gap. Needs its own spec: Google OAuth web client ID, `drive.appdata` scope, `--dart-define=GOOGLE_SERVER_CLIENT_ID` in release build, privacy-policy update to re-add the Drive section. |
| Delete an active item + undo toast | yes (#34) | habbits deletes habits (core UX) | Divergent-by-design | Different domain; no action. |

## Architecture / docs

| Item | nooka | habbits | Call | Recommendation |
|------|-------|---------|------|----------------|
| Architecture doc layout | grouped (`home-coordination.md`, `error-handling.md`, `archive.md`, single `i18n-theming.md`) | per-capability split (`habit-tracking.md`, `streaks-and-stats.md`, `reminders.md`, `i18n.md`, `theming.md`) | Divergent-by-design | Each reflects its app's capabilities; no action. |

## Build / deps

| Item | nooka | habbits | Call | Recommendation |
|------|-------|---------|------|----------------|
| AGP / Kotlin versions | 9.0.1 / 2.3.20 | 9.0.1 / 2.3.20 | Aligned | No action — already in sync. |
| App version | 1.2.2+6 | 1.0.0+1 | Expected skew | Independent release cadence; no action. |
| `pubspec.yaml` dependency set | includes Google Drive / OAuth deps | no Drive deps | Follows the Drive-backup decision | Revisit if Drive backup is ported. |

## Suggested next specs (in priority order)
1. Docs-only CI skip (tiny, mirrors nooka #37).
2. Google Drive cloud backup (large; own brainstorming cycle).
```

- [ ] **Step 2: Verify planning validation still passes**

Run:
```bash
just check-planning
```
Expected: passes (the loose audit file is not a bundle). If it complains about the file, move it to `docs/nooka-vs-habbits-audit.md` and re-run.

- [ ] **Step 3: Commit**

```bash
git add planning/nooka-vs-habbits-audit.md
git commit -m "docs(planning): nooka vs habbits cross-app audit

Standalone comparison of the two sibling apps across CI/CD, features,
architecture, and build. Tags each difference Portable / Divergent /
Aligned with a recommendation; flags docs-only CI skip and Google Drive
backup as the next candidate specs.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Final verification (after all tasks)

- [ ] **Repo-wide sanity**

```bash
just lint
just test
```
Expected: both green. This work touches no Dart logic, so `test` should be unchanged from `main`; `lint` confirms `dart format` is clean and `flutter analyze` has no new issues.

- [ ] **No stray `nooka` references in habbits-facing text**

```bash
grep -rin "nooka" README.md docs/rustore-release.md site/ .github/workflows/ android/app/build.gradle.kts
```
Expected: no hits (the audit doc legitimately mentions nooka; everything else must not).

- [ ] **Open the PR** (per the maintainer's workflow — push branch `rustore-publishing`, open a PR, never local-merge; watch CI). Use `superpowers:finishing-a-development-branch` to do this.

## Manual half (maintainer, out of band — documented in `docs/rustore-release.md`)

RuStore account + verification, create the app listing (package
`io.github.quotidianlabs.habbits`), generate the API key, add the
`RUSTORE_CREDENTIALS` secret, and enable GitHub Pages (Settings → Pages →
Source: GitHub Actions). CI stays inert until these exist.

## Self-Review notes

- **Spec coverage:** Part A → Task 1; Part B → Tasks 2-3; Part C → Task 4;
  Part D → Task 5; Part E → Task 6. All spec sections mapped.
- **Guard invariant** (spec Global Constraint): enforced and verified by reading
  in Task 3 Step 3.
- **No Google Drive** (spec constraint): privacy page verified Drive-free in
  Task 4 Step 4; runbook adapted in Task 5.
- **Package/asset naming** (`habbits`, not `nooka`): verified in Task 5 Step 4
  and the final grep.
```

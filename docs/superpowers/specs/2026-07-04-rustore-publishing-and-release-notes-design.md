# RuStore publishing + release-notes fix for habbits

Date: 2026-07-04
Status: Approved (brainstorming) — ready for implementation plan

## Problem

`habbits` and its sibling app `nooka` (at `../tasks`, package
`io.github.quotidianlabs.nooka`) are deliberately kept in sync on tooling.
`nooka` has moved ahead on release/store tooling and `habbits` should catch up:

1. **Release notes are required but then overridden.** Both apps' `release.yml`
   have an identical gate that aborts a stable tag lacking
   `planning/releases/<tag>.md`. But habbits' *publish* step hardcodes
   `generate_release_notes: true`, so GitHub appends its auto "What's Changed"
   on top of the curated notes. The curated notes the gate forces you to write
   are not used verbatim. nooka fixed this; habbits did not.
2. **No RuStore publishing.** nooka builds and uploads to RuStore (VK's Russian
   Android store) from CI, guarded so it no-ops without credentials. habbits has
   none of the gradle wiring, CI steps, privacy site, or runbook.
3. **No cross-app comparison.** We want a standalone audit of what else differs
   between the two apps, to decide later what to port (e.g. Google Drive backup).

## Goals

- Curated stable-tag release notes publish verbatim (no auto "What's Changed").
- habbits can publish to RuStore from CI on a stable tag, guarded so it stays
  inert until the RuStore account + `RUSTORE_CREDENTIALS` secret exist.
- A privacy-policy URL exists (RuStore requires one), served via GitHub Pages.
- A standalone audit doc comparing the two apps, with portability calls.

## Non-goals

- The manual RuStore half: account creation/verification, store listing, API key,
  adding the `RUSTORE_CREDENTIALS` secret, enabling GitHub Pages. Documented in
  the runbook; CI ships inert until done.
- Porting Google Drive backup or any other nooka feature — the audit *recommends*;
  each accepted item becomes its own future spec.
- Any change to Play Store (`.aab`) release flow in `docs/release.md`.

## Strategy

Mirror nooka's proven pattern, adapting content for habbits: a habit tracker
with **local-only data** (JSON export/import; no Google Drive backup). Package
name stays `io.github.quotidianlabs.habbits`. Org is `quotidianlabs`, so the
privacy URL is `https://quotidianlabs.github.io/habbits/privacy`.

## Design

### Part A — Release-notes fix (`.github/workflows/release.yml`)

Port nooka's conditional-notes logic:

- In the **Resolve release metadata** step, when
  `planning/releases/${GITHUB_REF_NAME}.md` exists, emit both
  `body_path=<that file>` and `generate_notes=false`; otherwise emit
  `generate_notes=true` (and no `body_path`).
- In **Publish GitHub Release**, replace `generate_release_notes: true` with
  `generate_release_notes: ${{ steps.meta.outputs.generate_notes }}`.

Effect: stable tags (already required to have curated notes by the existing
"Require curated release notes" step) publish the notes verbatim; pre-release
tags without a curated file keep the auto-generated fallback. Matches nooka's
`release.yml` lines 110-133.

### Part B — RuStore build + upload

- **`android/settings.gradle.kts`**: add to the `plugins { }` block
  `id("ru.cian.rustore-publish-gradle-plugin") version "0.5.5" apply false`.
- **`android/app/build.gradle.kts`**: apply `id("ru.cian.rustore-publish-gradle-plugin")`
  in `plugins { }`, and add a `rustorePublish { }` block after the `flutter { }`
  block, adapted from nooka:
  - `credentialsPath = "$rootDir/rustore-credentials.json"`
  - `buildFormat = APK`
  - `buildFile = "$rootDir/../build/app/outputs/flutter-apk/app-release.apk"`
  - `publishType = INSTANTLY`
  - `developerContacts`: email `me@shiriev.ru`,
    website `https://github.com/quotidianlabs/habbits`, `vkCommunity = null`
  - `releaseNotes`: one `ReleaseNote(lang = "ru-RU", filePath =
    "$rootDir/app/rustore-release-notes-ru.txt")`
  - Keep nooka's comment noting the block is inert unless `publishRustoreRelease`
    runs with a credentials file present.
- **`android/app/rustore-release-notes-ru.txt`** (new): RU notes. Default line
  matches nooka: `Исправления ошибок и улучшения стабильности.`
- **`android/.gitignore`**: add `rustore-credentials.json`.
- **`release.yml`**: after "Publish GitHub Release", append the two guarded steps
  from nooka (lines 136-161):
  - **Check RuStore credentials** (`id: rustore`): sets `enabled=true` only when
    the `RUSTORE_CREDENTIALS` secret is non-empty AND the tag is not a
    pre-release; otherwise logs a `::notice::` and sets `enabled=false`.
  - **Upload APK to RuStore** (`if: steps.rustore.outputs.enabled == 'true'`,
    `working-directory: android`): writes the secret to `rustore-credentials.json`
    and runs `./gradlew :app:publishRustoreRelease --buildFile=<renamed apk>`.
    The renamed APK is `habbits-${GITHUB_REF_NAME}.apk` (habbits' existing
    rename step), not nooka's `nooka-...`.

### Part C — Privacy site (GitHub Pages)

- **`.github/workflows/pages.yml`** (new): copy nooka's verbatim — triggers on
  `push` to `main` under `site/**` (and the workflow file) plus
  `workflow_dispatch`; least-privilege `pages: write` / `id-token: write`;
  `concurrency: pages`; uploads `site/` as static HTML and deploys via
  `actions/deploy-pages@v5`.
- **`site/index.html`** (new): adapted landing page — title `habbits`, one-line
  description "A local-first habit tracker for iOS and Android.", link to
  `privacy/`. Same minimal inline CSS as nooka.
- **`site/privacy/index.html`** (new): adapted from nooka's privacy page, trimmed
  for habbits' local-only reality:
  - Title/heading `Habbits — Privacy Policy`; `Last updated: 2026-07-04`.
  - Intro: local-first habit tracker; no server/backend, no account, no
    analytics, no ads, no tracking.
  - "Data stored on your device": habits + completions in an on-device SQLite
    database; OS-level backup (Android Auto Backup / iOS device backup) caveat.
  - **Remove** nooka's "Optional Google Drive backup" section entirely.
  - "Optional file export/import": JSON export via the share sheet and import;
    habbits does not upload it anywhere.
  - "Data sharing", "Deleting your data" (drop Drive-revocation sentence),
    "Children", "Contact" (`me@shiriev.ru`) — adapted from nooka.

### Part D — Docs + README

- **`docs/rustore-release.md`** (new): the manual runbook, adapted from nooka:
  - Package `io.github.quotidianlabs.habbits`.
  - Privacy URL `https://quotidianlabs.github.io/habbits/privacy`.
  - `RUSTORE_CREDENTIALS` secret JSON shape (`key_id` / `client_secret`).
  - Publish flow: bump `pubspec.yaml` `+N`, merge, push stable tag; CI builds
    signed APK and runs `publishRustoreRelease` (`INSTANTLY` → moderation).
  - "Notes" section adapted: **drop** the Google Drive / Play Services caveat
    (habbits has no Drive); keep "version code already used → bump `+N` and
    re-tag" and "a tag before the account/secret exists is fine — RuStore step
    skips with a notice, GitHub Release still ships".
- **`README.md`**: add a RuStore badge/link alongside the existing Release/CI/
  Coverage/License/Flutter badges (following nooka's `docs(readme)` pattern).
  Exact badge markup to match nooka's during implementation.
- **`docs/release.md`**: cross-check for a place to reference `rustore-release.md`
  (e.g. a "see also" line); no behavioral change to the Play `.aab` flow.

### Part E — Comparison audit doc

- **`planning/nooka-vs-habbits-audit.md`** (new): standalone report (lives under
  `planning/` per repo convention; not a release artifact). A table comparing the
  two apps across dimensions, each row tagged **Portable** / **Divergent-by-design**
  / **Skip** with a one-line recommendation:
  - **CI/CD**: docs-only CI skip (nooka `#37` has it; habbits does not →
    Portable); pages workflow (added here); release-notes divergence (closed here).
  - **Features**: Google Drive cloud backup (nooka `#32`/`#33`; habbits local
    JSON only → Portable, own spec); delete-active-item + undo toast (nooka `#34`);
    home-coordination differences.
  - **Architecture/docs**: doc layout (nooka `error-handling.md`, `archive.md`,
    `home-coordination.md`, single `i18n-theming.md` vs habbits' per-capability
    split) → Divergent-by-design.
  - **Build**: `settings.gradle.kts` — confirmed **already aligned** (both AGP
    9.0.1, Kotlin 2.3.20) → no action.
  - **Deps / versions**: `pubspec.yaml` diff; version skew (habbits `1.0.0+1`,
    nooka `1.2.2+6`).

## Testing / verification

- `just lint` and `just test` stay green (no Dart logic changes; work is
  CI/gradle/docs/HTML).
- **Gradle sanity (local, no upload)**: `cd android && ./gradlew tasks` lists
  `publishRustoreRelease` and configuration succeeds — proves the plugin resolves
  (version `0.5.5`) and the `rustorePublish` block is valid Kotlin DSL.
- **Guard proof (by reading)**: the upload step is `if: enabled == 'true'`, and
  `enabled` is false whenever `RUSTORE_CREDENTIALS` is empty — so merging this
  cannot attempt a RuStore upload until the secret is added. Confirmed by
  inspecting the rendered `release.yml`.
- **Pages**: `pages.yml` only serves static files; validity is confirmed by the
  workflow being copied verbatim from a working nooka deploy. Live serving
  requires the manual "enable Pages" step.

## Rollout / manual half (out of scope, in the runbook)

RuStore account + verification, create app listing (package
`io.github.quotidianlabs.habbits`), generate API key, add `RUSTORE_CREDENTIALS`
secret, enable GitHub Pages (Settings → Pages → Source: GitHub Actions). CI is
inert until these exist; the first RuStore upload may also be done manually in
the Console from the GitHub Release APK.

## Open questions

None blocking. RuStore release notes are RU-only (matching nooka, a Russian
store); revisit if a bilingual listing is later wanted.

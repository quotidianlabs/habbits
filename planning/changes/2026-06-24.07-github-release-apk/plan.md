---
status: draft
date: 2026-06-24
slug: github-release-apk
spec: github-release-apk
pr: null
---

# github-release-apk — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** On every `v*` git tag, build a signed universal release APK and
auto-publish a GitHub Release with the APK attached and notes from
`planning/releases/<semver>.md`.

**Architecture:** A single new GitHub Actions workflow (`release.yml`) triggered
on `push` of `v*` tags. It reconstructs `android/key.properties` + the keystore
from repo secrets, runs the existing (unchanged) Gradle release-signing path,
and publishes via `softprops/action-gh-release`. No app or Gradle code changes —
local proof already confirmed `flutter build apk --release` signs with the upload
key when `key.properties` is present.

**Tech Stack:** GitHub Actions, `subosito/flutter-action@v2` (Flutter 3.44.2
stable), `softprops/action-gh-release@v2`, Flutter Gradle Android build.

## Global Constraints

- Flutter version: **3.44.2**, channel **stable** — copy `ci.yml` verbatim.
- The build MUST be signed with the upload key, never the debug fallback — fail
  loudly if signing secrets are absent.
- Tag format is `vX.Y.Z`; it MUST equal `pubspec.yaml` `version: X.Y.Z+N` — fail
  on mismatch.
- Notes file convention: tag `vX.Y.Z` → `planning/releases/X.Y.Z.md` (no `v`).
- Release is **published** (`draft: false`), universal APK only.
- This is additive: do NOT touch `docs/release.md`'s `.aab` content or
  `android/app/build.gradle.kts`.
- Required repo secrets (added manually, out of plan scope):
  `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
  `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`.

---

## File Structure

- `.github/workflows/release.yml` — **create.** The whole feature. One job:
  validate → sign → build → publish.
- `docs/release.md` — **modify.** Append a "GitHub Release APK" section.
- `planning/releases/1.0.0.md` — **create.** Seeds the notes-file convention and
  gives the first release real notes.

---

### Task 1: Release workflow

**Files:**
- Create: `.github/workflows/release.yml`

**Interfaces:**
- Consumes: repo secrets `ANDROID_KEYSTORE_BASE64`,
  `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`;
  the existing `hasReleaseKeystore` logic in
  `android/app/build.gradle.kts:14-18,47-66` (reads `android/key.properties`,
  resolves `storeFile`).
- Produces: a published GitHub Release named `<tag>` with one asset
  `habbits-<tag>.apk`.

- [ ] **Step 1: Write the workflow file**

Create `.github/workflows/release.yml`:

```yaml
name: release

on:
  push:
    tags:
      - 'v*'

# Needed for softprops/action-gh-release to create the release.
permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: 3.44.2
          channel: stable
          cache: true

      # Tag vX.Y.Z must match pubspec.yaml `version: X.Y.Z+N`.
      - name: Verify tag matches pubspec version
        run: |
          set -euo pipefail
          tag="${GITHUB_REF_NAME#v}"
          pubspec="$(grep -E '^version:' pubspec.yaml \
            | sed -E 's/^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
          echo "tag=$tag pubspec=$pubspec"
          if [ "$tag" != "$pubspec" ]; then
            echo "::error::Tag v$tag does not match pubspec version $pubspec"
            exit 1
          fi

      # Reconstruct the signing keystore from secrets (see docs/release.md).
      - name: Decode signing keystore
        env:
          KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
        run: |
          set -euo pipefail
          if [ -z "${KEYSTORE_BASE64:-}" ]; then
            echo "::error::ANDROID_KEYSTORE_BASE64 secret is empty or missing"
            exit 1
          fi
          echo "$KEYSTORE_BASE64" | base64 --decode > android/upload-keystore.jks
          if [ ! -s android/upload-keystore.jks ]; then
            echo "::error::Decoded keystore is empty — refusing to debug-sign"
            exit 1
          fi

      - name: Write key.properties
        env:
          STORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
          KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
        run: |
          set -euo pipefail
          {
            echo "storePassword=$STORE_PASSWORD"
            echo "keyPassword=$KEY_PASSWORD"
            echo "keyAlias=$KEY_ALIAS"
            echo "storeFile=$GITHUB_WORKSPACE/android/upload-keystore.jks"
          } > android/key.properties

      - run: flutter pub get

      - name: Build signed release APK
        run: flutter build apk --release

      - name: Rename APK
        run: |
          set -euo pipefail
          mv build/app/outputs/flutter-apk/app-release.apk \
             "build/app/outputs/flutter-apk/habbits-${GITHUB_REF_NAME}.apk"

      # tag vX.Y.Z -> planning/releases/X.Y.Z.md (omit body_path if absent).
      - name: Resolve release notes file
        id: notes
        run: |
          set -euo pipefail
          version="${GITHUB_REF_NAME#v}"
          path="planning/releases/${version}.md"
          if [ -f "$path" ]; then
            echo "body_path=$path" >> "$GITHUB_OUTPUT"
          fi

      - name: Publish GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: build/app/outputs/flutter-apk/habbits-${{ github.ref_name }}.apk
          body_path: ${{ steps.notes.outputs.body_path }}
          generate_release_notes: true
          draft: false
```

- [ ] **Step 2: Validate the YAML parses**

Run:
```bash
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/release.yml')); print('YAML OK')"
```
Expected: `YAML OK` (no traceback).

- [ ] **Step 3: Sanity-check the trigger and key steps with yq**

Run:
```bash
yq '.on.push.tags' .github/workflows/release.yml
yq '.jobs.release.steps[].name' .github/workflows/release.yml
```
Expected: tags shows `- v*`; step names include `Verify tag matches pubspec
version`, `Decode signing keystore`, `Write key.properties`, `Build signed
release APK`, `Rename APK`, `Resolve release notes file`, `Publish GitHub
Release`.

- [ ] **Step 4: Confirm no app/Gradle files changed**

Run:
```bash
git status --porcelain
```
Expected: only `.github/workflows/release.yml` is new/modified — no changes to
`android/` or `lib/`.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: build signed release APK and publish to GitHub Releases on v* tags

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Docs + first release notes

**Files:**
- Modify: `docs/release.md` (append a new section at end, after line 89)
- Create: `planning/releases/1.0.0.md`

**Interfaces:**
- Consumes: nothing.
- Produces: `planning/releases/1.0.0.md`, which Task 1's "Resolve release notes
  file" step reads as `body_path` when tag `v1.0.0` is pushed.

- [ ] **Step 1: Append the GitHub Release APK section to docs/release.md**

Add to the end of `docs/release.md`:

```markdown

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
```

- [ ] **Step 2: Create the first release notes file**

Create `planning/releases/1.0.0.md`:

```markdown
# Habbits 1.0.0

First public release.

- Local-first habit tracker for iOS and Android.
- Daily habit toggling with streak tracking.
- Reminders via local notifications.
- English and Russian localization.
```

- [ ] **Step 3: Verify the notes path resolves as the workflow expects**

Run:
```bash
test -f planning/releases/1.0.0.md && echo "notes file OK for tag v1.0.0"
```
Expected: `notes file OK for tag v1.0.0`.

- [ ] **Step 4: Commit**

```bash
git add docs/release.md planning/releases/1.0.0.md
git commit -m "docs: document GitHub Release APK channel; seed 1.0.0 notes

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Ship-time bookkeeping

**Files:**
- Modify: `planning/changes/2026-06-24.07-github-release-apk/change.md`
  (frontmatter)
- Modify: `planning/changes/2026-06-24.07-github-release-apk/plan.md`
  (frontmatter)

- [ ] **Step 1: Mark the bundle shipped**

In `change.md` frontmatter set `status: shipped`, `pr: <PR number>`, and
`outcome:` to a one-line result. In `plan.md` frontmatter set `pr: <PR number>`.

- [ ] **Step 2: Confirm the index reflects it**

Run:
```bash
just index | grep github-release-apk
```
Expected: the bundle appears under the **Shipped** group.

- [ ] **Step 3: Commit**

```bash
git add planning/changes/2026-06-24.07-github-release-apk/
git commit -m "docs(planning): mark github-release-apk shipped

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Post-merge verification (manual, after secrets added)

Cannot be tested in CI before merge — requires the real secrets and tag push:

- [ ] Add the four secrets to the GitHub repo.
- [ ] `git tag v1.0.0 && git push origin v1.0.0`.
- [ ] The `release` workflow succeeds; Release `v1.0.0` is published with
      `habbits-v1.0.0.apk` attached and the 1.0.0 notes + auto PR list as body.
- [ ] `apksigner verify --print-certs habbits-v1.0.0.apk` → upload-key cert
      (SHA-256 `47ff808c…`), not `CN=Android Debug`.
- [ ] APK installs on a device.
- [ ] Negative check: pushing a tag that mismatches `pubspec.yaml` version fails
      at the "Verify tag matches pubspec version" step.

---

## Self-Review

- **Spec coverage:** trigger (Task 1 `on.push.tags`), signing reconstruction +
  guard (Task 1 decode/write steps), version guard (Task 1), universal build +
  rename (Task 1), notes resolution (Task 1 + `planning/releases/1.0.0.md` in
  Task 2), auto-publish (Task 1 `draft: false`), docs + caveat (Task 2),
  ship bookkeeping (Task 3). All spec points mapped.
- **Placeholders:** none — every step has concrete content; `<PR number>` in
  Task 3 is a genuine fill-at-ship value, not a code placeholder.
- **Type/name consistency:** asset name `habbits-${GITHUB_REF_NAME}.apk` /
  `habbits-${{ github.ref_name }}.apk` matches between rename and publish;
  notes path `planning/releases/${version}.md` matches Task 2's
  `planning/releases/1.0.0.md`; secret names match the spec's Global Constraints.

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

---
summary: Activity-grid app icon + bundle id `io.github.quotidianlabs.habbits`.
---

# App icon + branding — design

**Date:** 2026-06-15
**Status:** Approved (pending spec review)

## Goal

Replace the default Flutter launcher icon and the placeholder `com.example.habbits`
identifier with real branding: a custom **activity-grid** app icon and the
application/bundle id **`io.github.quotidianlabs.habbits`**, applied to both iOS
and Android, with the visible app name "Habbits". No Dart/behavior change — this
is platform config + image assets.

Non-goals: App Store / Play Store registration; a splash/launch screen redesign;
README/LICENSE (separate follow-up).

## 1. Application / bundle id → `io.github.quotidianlabs.habbits`

GitHub org `quotidianlabs` is registered (`io.github.<org>` is the open-source
convention; no hyphens, so it is a valid package id).

**Android** (`android/app/build.gradle.kts`):
- `namespace = "io.github.quotidianlabs.habbits"`
- `applicationId = "io.github.quotidianlabs.habbits"`
- Because `namespace` changes, **move `MainActivity.kt`** from
  `android/app/src/main/kotlin/com/example/habbits/MainActivity.kt` to
  `android/app/src/main/kotlin/io/github/quotidianlabs/habbits/MainActivity.kt`
  and change its `package com.example.habbits` → `package io.github.quotidianlabs.habbits`.
  Remove the now-empty `com/example/habbits` dirs. (The manifest references the
  activity as `.MainActivity` relative to the namespace, so no manifest edit is
  needed for that — verify.)

**iOS** (`ios/Runner.xcodeproj/project.pbxproj`):
- Replace every `PRODUCT_BUNDLE_IDENTIFIER = com.example.habbits;` →
  `io.github.quotidianlabs.habbits;` (the Runner target's Debug/Release/Profile
  configs).
- The RunnerTests configs (`com.example.habbits.RunnerTests`) become
  `io.github.quotidianlabs.habbits.RunnerTests`. A single replace of the string
  `com.example.habbits` → `io.github.quotidianlabs.habbits` across the file
  handles both (RunnerTests keeps its `.RunnerTests` suffix automatically).

**Note:** changing the Android `applicationId` makes this a *new* app identity —
no in-place upgrade over old `com.example.habbits` installs, and the on-device
Drift DB starts fresh. Acceptable (pre-release).

## 2. Visible app name → "Habbits"

- Android `android/app/src/main/AndroidManifest.xml`: `android:label="habbits"` →
  `android:label="Habbits"`.
- iOS `ios/Runner/Info.plist`: `CFBundleDisplayName` is already `Habbits` (leave).
  `CFBundleName` (`habbits`) is not user-visible when DisplayName is set — leave.

## 3. Icon asset — activity grid (approved concept B)

Brand teal `#009688`, a 3×3 grid of white squares with a couple at reduced
opacity (echoes the app's day-strip/heat-map). Generated for all platforms from
source art via the standard **`flutter_launcher_icons`** package.

### Source art (committed under `assets/icon/`)
SVG is the source of truth; PNGs are rendered from it and committed so the build
never needs the renderer.

`assets/icon/icon.svg` — full-bleed square (teal fills to the edges; iOS/legacy
Android apply their own corner mask, so the source must NOT be pre-rounded):
```svg
<svg viewBox="0 0 220 220" xmlns="http://www.w3.org/2000/svg">
  <rect width="220" height="220" fill="#009688"/>
  <g fill="#ffffff">
    <rect x="62"  y="62"  width="26" height="26" rx="6" opacity="1"/>
    <rect x="97"  y="62"  width="26" height="26" rx="6" opacity="0.35"/>
    <rect x="132" y="62"  width="26" height="26" rx="6" opacity="1"/>
    <rect x="62"  y="97"  width="26" height="26" rx="6" opacity="1"/>
    <rect x="97"  y="97"  width="26" height="26" rx="6" opacity="1"/>
    <rect x="132" y="97"  width="26" height="26" rx="6" opacity="0.35"/>
    <rect x="62"  y="132" width="26" height="26" rx="6" opacity="0.35"/>
    <rect x="97"  y="132" width="26" height="26" rx="6" opacity="1"/>
    <rect x="132" y="132" width="26" height="26" rx="6" opacity="1"/>
  </g>
</svg>
```

`assets/icon/icon_foreground.svg` — the grid only, on a transparent canvas, for
the Android adaptive foreground (the teal comes from the background color). Same
grid geometry, centered (the grid spans the central ~44% of the canvas — well
inside Android's 66% adaptive safe zone, so masking never clips it):
```svg
<svg viewBox="0 0 220 220" xmlns="http://www.w3.org/2000/svg">
  <g fill="#ffffff">
    <rect x="62"  y="62"  width="26" height="26" rx="6" opacity="1"/>
    <rect x="97"  y="62"  width="26" height="26" rx="6" opacity="0.35"/>
    <rect x="132" y="62"  width="26" height="26" rx="6" opacity="1"/>
    <rect x="62"  y="97"  width="26" height="26" rx="6" opacity="1"/>
    <rect x="97"  y="97"  width="26" height="26" rx="6" opacity="1"/>
    <rect x="132" y="97"  width="26" height="26" rx="6" opacity="0.35"/>
    <rect x="62"  y="132" width="26" height="26" rx="6" opacity="0.35"/>
    <rect x="97"  y="132" width="26" height="26" rx="6" opacity="1"/>
    <rect x="132" y="132" width="26" height="26" rx="6" opacity="1"/>
  </g>
</svg>
```

Rendered (committed): `assets/icon/icon.png` (1024×1024) and
`assets/icon/icon_foreground.png` (1024×1024, transparent).

### Rendering the PNGs
Render the SVGs to 1024×1024 PNGs with whatever is installed, preferred order:
`rsvg-convert -w 1024 -h 1024 icon.svg -o icon.png` → ImageMagick
(`magick -background none icon.svg -resize 1024x1024 icon.png`) → a small
throwaway script. The foreground render must preserve transparency.

### `flutter_launcher_icons` config (in `pubspec.yaml`)
```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.0

flutter_launcher_icons:
  image_path: "assets/icon/icon.png"
  android: true
  ios: true
  remove_alpha_ios: true
  adaptive_icon_background: "#009688"
  adaptive_icon_foreground: "assets/icon/icon_foreground.png"
  min_sdk_android: 21
```
Running `dart run flutter_launcher_icons` regenerates:
- iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/*` (+ `Contents.json`).
- Android: `mipmap-*/ic_launcher.png`, `mipmap-anydpi-v26/ic_launcher.xml`
  (adaptive), and the `#009688` background resource.

The `assets/icon/` source files do NOT need to be declared under `flutter:
assets:` (they're build-time inputs, not bundled runtime assets).

## 4. Testing / verification

- `flutter pub get` then `dart run flutter_launcher_icons` (regenerates icons).
- `flutter analyze` clean; full test suite green (no Dart changes; the
  RunnerTests bundle-id change keeps the iOS test target building).
- Build **both** platforms and confirm the new icon + "Habbits" name on the
  launcher/home screen (screenshot). Render `icon.png` and review it at small
  size before finalizing — nudge grid opacity/weight if it reads muddy.
- Verify the id in the built artifacts: Android `aapt dump badging
  build/app/outputs/flutter-apk/app-release.apk | grep package` →
  `io.github.quotidianlabs.habbits`; iOS `CFBundleIdentifier` resolves to the
  same.

## 5. Risks / notes

- Keep the existing `dependency_overrides: flutter_plugin_android_lifecycle:
  2.0.22` intact (required for the Android release build).
- `flutter_launcher_icons` produces a large but fully-generated diff (many PNGs +
  `Contents.json`). Commit it.
- The simulator/emulator must be cold-restarted (or the app reinstalled) to drop
  the OS icon cache when verifying.
- Done on a branch → PR to `origin` (the now-public repo), not committed straight
  to `main`.

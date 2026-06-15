---
status: shipped
date: 2026-06-15
slug: app-icon-branding
spec: app-icon-branding
pr: "#1 (bbb0a93)"
---

# App Icon + Branding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the default Flutter icon and `com.example.habbits` with the activity-grid icon and the id `io.github.quotidianlabs.habbits` on iOS + Android, with the app name "Habbits".

**Architecture:** Pure platform-config + image-asset change (no Dart/behavior change). Bundle id edited in Gradle + Xcode project; icon authored as committed SVG, rendered to PNG via `librsvg`, and expanded to all platform sizes by `flutter_launcher_icons` (incl. an Android adaptive icon).

**Tech Stack:** Flutter 3.44, `flutter_launcher_icons`, `librsvg` (`rsvg-convert`), Gradle (Kotlin DSL), Xcode pbxproj.

**Spec:** `docs/superpowers/specs/2026-06-15-app-icon-branding-design.md`

**Conventions:**
- `export PATH="/opt/homebrew/bin:$PATH"` before flutter/dart/brew commands.
- This is config/assets — there are **no Dart unit tests to add**. The gate for every task is: `flutter analyze` clean + `flutter test` green (115 tests) + the relevant platform build succeeds. Do NOT weaken or delete existing tests.
- Keep `dependency_overrides: flutter_plugin_android_lifecycle: 2.0.22` intact.
- Work on a branch; final PR targets `origin` (public repo).

**Pre-flight:**
```bash
export PATH="/opt/homebrew/bin:$PATH"
flutter analyze && flutter test   # baseline: clean + 115 passing
```

---

## Task 1: Android application id + MainActivity move + label

**Files:**
- Modify: `android/app/build.gradle.kts`
- Move: `android/app/src/main/kotlin/com/example/habbits/MainActivity.kt` → `android/app/src/main/kotlin/io/github/quotidianlabs/habbits/MainActivity.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Change `namespace` and `applicationId`** in `android/app/build.gradle.kts`:
  - Line `namespace = "com.example.habbits"` → `namespace = "io.github.quotidianlabs.habbits"`
  - Line `applicationId = "com.example.habbits"` → `applicationId = "io.github.quotidianlabs.habbits"`
  - Delete the stale `// TODO: Specify your own unique Application ID ...` comment above `applicationId` (it's now done).

- [ ] **Step 2: Move MainActivity to the new package path**
```bash
cd /Users/kevinsmith/src/habbits
mkdir -p android/app/src/main/kotlin/io/github/quotidianlabs/habbits
git mv android/app/src/main/kotlin/com/example/habbits/MainActivity.kt \
       android/app/src/main/kotlin/io/github/quotidianlabs/habbits/MainActivity.kt
```
Then edit the moved file's first line `package com.example.habbits` → `package io.github.quotidianlabs.habbits`. Full file becomes:
```kotlin
package io.github.quotidianlabs.habbits

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
```
Remove the now-empty old dirs:
```bash
rmdir android/app/src/main/kotlin/com/example/habbits android/app/src/main/kotlin/com/example android/app/src/main/kotlin/com 2>/dev/null; true
```

- [ ] **Step 3: Set the display name** in `android/app/src/main/AndroidManifest.xml`: change `android:label="habbits"` → `android:label="Habbits"`. (Leave `android:name="${applicationName}"` and the activity's `android:name=".MainActivity"` — the latter resolves against the new namespace.)

- [ ] **Step 4: Build the Android app to verify the rename compiles + runs the new MainActivity**
```bash
export PATH="/opt/homebrew/bin:$PATH"
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export JAVA_HOME=/opt/homebrew/opt/openjdk@17
flutter build apk --debug
```
Expected: build succeeds (`✓ Built build/app/outputs/flutter-apk/app-debug.apk`). Then confirm the id baked in:
```bash
"$ANDROID_HOME"/build-tools/36.0.0/aapt dump badging build/app/outputs/flutter-apk/app-debug.apk | grep -E "package: name|application-label"
```
Expected: `package: name='io.github.quotidianlabs.habbits'` and `application-label:'Habbits'`.

- [ ] **Step 5: Confirm Dart suite unaffected**
```bash
flutter analyze && flutter test
```
Expected: clean + 115 pass.

- [ ] **Step 6: Commit**
```bash
git add android/
git commit -m "chore(android): set applicationId io.github.quotidianlabs.habbits + app name

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: iOS bundle identifier

**Files:**
- Modify: `ios/Runner.xcodeproj/project.pbxproj`

- [ ] **Step 1: Replace the bundle id in all 6 build configs** (3 Runner + 3 RunnerTests). A single string replace is correct — RunnerTests keeps its `.RunnerTests` suffix:
```bash
cd /Users/kevinsmith/src/habbits
sed -i '' 's/com\.example\.habbits/io.github.quotidianlabs.habbits/g' ios/Runner.xcodeproj/project.pbxproj
grep -n "PRODUCT_BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/project.pbxproj
```
Expected: 6 lines — 3 reading `io.github.quotidianlabs.habbits;` and 3 reading `io.github.quotidianlabs.habbits.RunnerTests;`. Confirm NO `com.example.habbits` remains:
```bash
grep -c "com.example.habbits" ios/Runner.xcodeproj/project.pbxproj   # expect 0
```

- [ ] **Step 2: Build the iOS app (simulator) to verify the project still configures + the id is applied**
```bash
export PATH="/opt/homebrew/bin:$PATH"
flutter build ios --simulator --debug
/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" build/ios/iphonesimulator/Runner.app/Info.plist
```
Expected: build succeeds; `CFBundleIdentifier` prints `io.github.quotidianlabs.habbits`.

- [ ] **Step 3: Confirm Dart suite unaffected**
```bash
flutter analyze && flutter test
```
Expected: clean + 115 pass.

- [ ] **Step 4: Commit**
```bash
git add ios/Runner.xcodeproj/project.pbxproj
git commit -m "chore(ios): set bundle id io.github.quotidianlabs.habbits

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Icon source art + rendered PNGs

**Files:**
- Create: `assets/icon/icon.svg`, `assets/icon/icon_foreground.svg`
- Create (generated, committed): `assets/icon/icon.png`, `assets/icon/icon_foreground.png`

- [ ] **Step 1: Create `assets/icon/icon.svg`** (full-bleed teal square + white grid; NOT pre-rounded — the OS masks corners):
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

- [ ] **Step 2: Create `assets/icon/icon_foreground.svg`** (grid only on transparent — Android adaptive foreground; teal comes from the background color):
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

- [ ] **Step 3: Install the SVG renderer and render both PNGs at 1024×1024**
```bash
export PATH="/opt/homebrew/bin:$PATH"
command -v rsvg-convert >/dev/null || brew install librsvg
cd /Users/kevinsmith/src/habbits
rsvg-convert -w 1024 -h 1024 assets/icon/icon.svg            -o assets/icon/icon.png
rsvg-convert -w 1024 -h 1024 assets/icon/icon_foreground.svg -o assets/icon/icon_foreground.png
```

- [ ] **Step 4: Verify the rendered PNGs**
```bash
file assets/icon/icon.png assets/icon/icon_foreground.png
```
Expected: both `PNG image data, 1024 x 1024`. The implementer should also open/Read `assets/icon/icon.png` to confirm it's a teal square with the white 3×3 grid (two cells faded), and `icon_foreground.png` is the grid on transparency.

- [ ] **Step 5: Commit**
```bash
git add assets/icon/
git commit -m "feat(branding): add activity-grid app icon source (svg) + 1024 png

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Generate platform icons with flutter_launcher_icons

**Files:**
- Modify: `pubspec.yaml`
- Generated (committed): `ios/Runner/Assets.xcassets/AppIcon.appiconset/*`, `android/app/src/main/res/mipmap-*/`, `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`, `android/app/src/main/res/values/colors.xml` (adaptive background)

- [ ] **Step 1: Add the dev dependency + config to `pubspec.yaml`**
Under `dev_dependencies:` add:
```yaml
  flutter_launcher_icons: ^0.14.0
```
At the top level of `pubspec.yaml` (e.g. after the `flutter:` block), add:
```yaml
flutter_launcher_icons:
  image_path: "assets/icon/icon.png"
  android: true
  ios: true
  remove_alpha_ios: true
  adaptive_icon_background: "#009688"
  adaptive_icon_foreground: "assets/icon/icon_foreground.png"
  min_sdk_android: 21
```

- [ ] **Step 2: Fetch deps and generate the icons**
```bash
export PATH="/opt/homebrew/bin:$PATH"
flutter pub get
dart run flutter_launcher_icons
```
Expected: prints progress and "Successfully generated launcher icons" (or equivalent), with no errors.

- [ ] **Step 3: Verify generation**
```bash
ls android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml \
   android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png \
   ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json
grep -rn "009688" android/app/src/main/res/ | head
flutter analyze
```
Expected: the adaptive XML, a generated mipmap PNG, and the iOS Contents.json all exist; the teal background color is present in the Android resources; `flutter analyze` clean.

- [ ] **Step 4: Commit**
```bash
git add pubspec.yaml pubspec.lock android/app/src/main/res ios/Runner/Assets.xcassets
git commit -m "feat(branding): generate iOS + adaptive Android launcher icons

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Final verification + visual smoke test

**Files:** none (verification only)

- [ ] **Step 1: Full analyze + test**
```bash
export PATH="/opt/homebrew/bin:$PATH"
flutter analyze && flutter test
```
Expected: "No issues found!" + 115 pass.

- [ ] **Step 2: Build both platforms with the new id + icon**
```bash
export PATH="/opt/homebrew/bin:$PATH"
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export JAVA_HOME=/opt/homebrew/opt/openjdk@17
flutter build apk --release
flutter build ios --simulator --debug
```
Expected: both succeed. Re-confirm ids:
```bash
"$ANDROID_HOME"/build-tools/36.0.0/aapt dump badging build/app/outputs/flutter-apk/app-release.apk | grep -E "package: name|application-label"
/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" build/ios/iphonesimulator/Runner.app/Info.plist
```
Expected: `io.github.quotidianlabs.habbits` + label `Habbits` (Android); `io.github.quotidianlabs.habbits` (iOS).

- [ ] **Step 3: Visually confirm the launcher icon + name on the iOS simulator**
Install (do NOT launch) so the springboard shows the icon, then screenshot the home screen:
```bash
export PATH="/opt/homebrew/bin:$PATH"
xcrun simctl bootstatus habbits_ios -b
# clear any cached old install first
xcrun simctl uninstall habbits_ios io.github.quotidianlabs.habbits 2>/dev/null; true
xcrun simctl uninstall habbits_ios com.example.habbits 2>/dev/null; true
xcrun simctl install habbits_ios build/ios/iphonesimulator/Runner.app
xcrun simctl io habbits_ios screenshot /tmp/habbits_icon_springboard.png
```
Open/Read `/tmp/habbits_icon_springboard.png` and confirm the teal activity-grid icon appears under the name "Habbits". If the icon looks muddy/low-contrast at small size, adjust the faded cells' opacity in the SVGs (e.g. `0.35` → `0.45`), re-render (Task 3 Step 3), regenerate (Task 4 Step 2), and re-screenshot.

- [ ] **Step 4: (Optional) Android emulator visual check** — boot `habbits_test`, `flutter install`, and view the launcher/app-drawer icon. Skip if the iOS check + `aapt` confirmation are sufficient.

- [ ] **Step 5: Done** — no commit (verification only). Hand back for branch finish (PR to `origin`).

---

## Self-Review notes (for the executor)

- **Spec coverage:** Android id+MainActivity+label (T1), iOS bundle id incl. RunnerTests (T2), icon source SVG + rendered PNG (T3), `flutter_launcher_icons` config + adaptive Android + iOS appicon generation (T4), build/verify/visual-confirm incl. `aapt`/plist id checks (T5). Display name "Habbits" set on Android (T1); iOS `CFBundleDisplayName` already "Habbits".
- **No behavior change:** no Dart edits; every task gates on `flutter analyze` + 115 tests.
- **Renderer:** none was installed; T3 installs `librsvg` via brew (the user's package manager) and renders from the canonical SVG. PNGs are committed so later builds need no renderer.
- **Irreversibility note:** the Android `applicationId` change is a new app identity (no upgrade over `com.example`, fresh local DB) — acceptable pre-release, stated in the spec.

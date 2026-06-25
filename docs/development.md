# Local development setup

How to build, run, and test Habbits on a local device/emulator. CI runs its own
Android emulator and the test suite — this is for working locally. The values
below (Homebrew paths, tool versions) are a known-good **macOS + Homebrew**
setup; adapt as needed.

The everyday commands are in the [`Justfile`](../Justfile): `just lint`,
`just test`. Cutting an Android release build is covered in
[`release.md`](release.md).

## Android emulator & integration tests

The widget/unit suite (`just test`) needs no device. The **integration tests**
in [`integration_test/`](../integration_test/) (`critical_flow_test.dart`,
`screenshots_test.dart`) run against a booted Android emulator.

One-time toolchain (Homebrew, no sudo):

- Android command-line tools — `ANDROID_HOME=/opt/homebrew/share/android-commandlinetools`
- JDK — `openjdk@17` at `/opt/homebrew/opt/openjdk@17` (the `temurin` cask needs sudo; this one doesn't)
- SDK packages — `platform-tools`, `emulator`, `platforms;android-36`, `build-tools;36.0.0`, `system-images;android-36;google_apis;arm64-v8a` (the first Gradle build also pulls NDK + CMake)
- AVD — **`habbits_test`** (android-36, arm64-v8a)
- Wire Flutter to them once:
  ```bash
  flutter config --android-sdk "$ANDROID_HOME"
  flutter config --jdk-dir /opt/homebrew/opt/openjdk@17
  ```

Run an integration test:

```bash
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export JAVA_HOME=/opt/homebrew/opt/openjdk@17
export PATH="/opt/homebrew/bin:$JAVA_HOME/bin:$PATH"

# 1. boot headless; wait until `adb shell getprop sys.boot_completed` returns 1
"$ANDROID_HOME/emulator/emulator" -avd habbits_test \
  -no-window -no-audio -no-boot-anim -no-snapshot -gpu swiftshader_indirect &

# 2. run
flutter test integration_test/critical_flow_test.dart -d emulator-5554

# 3. teardown
adb -s emulator-5554 emu kill
```

**Gotcha:** the integration tests use a `pumpUntilFound` helper rather than
`pumpAndSettle`. The on-device file-backed SQLite check-off write propagates
through the Drift stream on the event loop, so `pumpAndSettle` can return before
the UI reflects the change.

## iOS Simulator

iOS is buildable/runnable on the Simulator. Some steps need a real terminal
(TTY) and Apple toolchain that can't run headless.

One-time toolchain (user-installed; the `sudo`/App Store steps can't run through
a non-interactive shell):

- **Xcode** at `/Applications/Xcode.app` — select it once in a real terminal:
  ```bash
  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
  sudo xcodebuild -runFirstLaunch
  sudo xcodebuild -license accept
  ```
  (These fail through a non-TTY shell with "a terminal is required to read the password".)
- **iOS Simulator runtime** — `xcodebuild -downloadPlatform iOS` (a large download). Device *types* ship with Xcode, but `simctl list runtimes` is empty until the runtime is downloaded.
- **CocoaPods** via `brew install cocoapods` is only needed by tooling — this app uses Swift Package Manager, not Pods (see gotchas).

Build & run on the Simulator (substitute your installed iOS runtime version):

```bash
export PATH="/opt/homebrew/bin:$PATH"
xcrun simctl create "habbits_ios" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-16 \
  com.apple.CoreSimulator.SimRuntime.iOS-26-5
xcrun simctl boot habbits_ios && open -a Simulator

flutter build ios --simulator --debug          # cold build is slow (SPM fetches); incremental ~seconds
xcrun simctl install habbits_ios build/ios/iphonesimulator/Runner.app
xcrun simctl launch habbits_ios io.github.quotidianlabs.habbits
xcrun simctl io habbits_ios screenshot /tmp/shot.png   # the debug first frame takes a moment
```

**Gotchas:**

- **Swift Package Manager, not CocoaPods.** Flutter 3.44 resolves iOS plugins via
  SPM — there is no `ios/Podfile`. `file_picker` pulls
  DKImagePickerController/SDWebImage/etc. via SPM on the first build. The SPM
  pins live in `ios/**/xcshareddata/swiftpm/Package.resolved` — **commit them**.
- **Notification delegate.** `AppDelegate.swift` uses Flutter 3.44's
  `FlutterImplicitEngineDelegate` / UIScene template. `flutter_local_notifications`
  requires setting `UNUserNotificationCenter.current().delegate = self as?
  UNUserNotificationCenterDelegate` in `didFinishLaunchingWithOptions` — without
  it, foreground reminders don't show and tap callbacks don't fire. Local
  notifications need no Info.plist keys (permission is requested at runtime via
  `IOSFlutterLocalNotificationsPlugin.requestPermissions`).
- **Bundle id** is `io.github.quotidianlabs.habbits` (matches Android's
  `applicationId`).
- The `share_plus` iPad popover anchor (`sharePositionOrigin`) is a known gap —
  tracked in [`planning/deferred.md`](../planning/deferred.md).

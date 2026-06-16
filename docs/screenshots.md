# Regenerating the README screenshots

The screenshots in [`README.md`](../README.md) live in
[`assets/screenshots/`](../assets/screenshots/) and are generated
deterministically — never hand-captured — so they stay consistent and easy to
refresh when the UI changes.

## How it works

- **Test:** [`integration_test/screenshots_test.dart`](../integration_test/screenshots_test.dart)
  pumps the real [`HabbitsApp`](../lib/main.dart) with three overrides: a seeded
  in-memory database (`seededDb()` — four habits with palette colors and recent
  completions), a no-op `NotificationService`, and a mocked `SharedPreferences`
  so the locale and theme are forced per shot (`{'theme': 'dark'}`,
  `{'locale': 'ru'}`, …). It navigates the live screens and calls
  `binding.takeScreenshot('<name>')` at each point.
- **Driver:** [`test_driver/integration_test.dart`](../test_driver/integration_test.dart)
  receives each shot via `onScreenshot` and writes
  `assets/screenshots/<name>.png`.
- Each `takeScreenshot('<name>')` maps 1:1 to `assets/screenshots/<name>.png`,
  which the README references by that filename.

## Regenerate

Run on the iOS simulator (matches the committed shots — iPhone 16, native
1179×2556). Setup notes for the toolchain are in the session memory
(`ios-build-setup`).

```bash
export PATH="/opt/homebrew/bin:$PATH"
xcrun simctl boot habbits_ios && open -a Simulator      # if not already booted
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart \
  -d habbits_ios
```

The PNGs are overwritten in place; review the diff and commit them with the
README change. (Android also works — the test guards the Android-only
`convertFlutterSurfaceToImage()`; that emulator's resolution differs from the
committed shots.)

## Add or change a shot

1. Add a `takeScreenshot('<name>')` (and any navigation) in
   `screenshots_test.dart`. To control locale/theme, pass prefs to `pumpApp`
   (e.g. `await pumpApp(tester, {'theme': 'dark'})`). Unfocus before capturing a
   dialog to hide the keyboard (see the color-picker shot).
2. Adjust the seed data in `seededDb()` if the screen needs different content.
3. Re-run the command above, then reference `assets/screenshots/<name>.png` in
   the README table.

## Current shots

`home-en`, `detail-en`, `settings-en`, `create-en` (color picker), `home-ru`,
`home-dark`.

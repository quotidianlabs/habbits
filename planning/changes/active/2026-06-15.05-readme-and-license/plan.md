---
status: draft
date: 2026-06-15
slug: readme-and-license
spec: readme-and-license
pr: null
---

# readme-and-license — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an MIT `LICENSE`, four en/ru app screenshots under `assets/screenshots/`, and a root `README.md` that shows the app off.

**Spec:** [`design.md`](./design.md)

**Branch:** `docs/readme-and-license`

**Commit strategy:** Per-task commits.

**Conventions:**
- `export PATH="/opt/homebrew/bin:$PATH"` first. Stage explicit paths only.
- Gate: `flutter analyze` clean + `flutter test` = 115 (this change adds an integration-test file that is NOT run by `flutter test`; the unit suite stays 115).
- Sequenced AFTER `ci-and-justfile` (the README's CI badge needs `ci.yml` to exist). Branch from the latest `main` that includes that change.

**Pre-flight:**
```bash
export PATH="/opt/homebrew/bin:$PATH"
flutter analyze && flutter test
git switch -c docs/readme-and-license
```

---

## Task 1: MIT LICENSE

**Files:** Create `LICENSE` (repo root).

- [ ] **Step 1: Create `LICENSE`** — standard MIT text:
```
MIT License

Copyright (c) 2026 quotidianlabs

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 2: Commit**
```bash
git add LICENSE
git commit -m "docs: add MIT license (c) 2026 quotidianlabs

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Generate the four screenshots

Real-text app screenshots require a real renderer, so this drives the app on the booted **iOS simulator** (`habbits_ios`) via `integration_test` + `flutter drive`, seeding sample habits and navigating to each screen. **This is the most finicky task — iterate until the four PNGs render correctly (real text, populated screens); if iOS surface-capture misbehaves, fall back to the Android emulator `habbits_test`.**

**Files:**
- Create: `test_driver/integration_test.dart`
- Create: `integration_test/screenshots_test.dart`
- Produces (committed): `assets/screenshots/{home-en,home-ru,detail-en,settings-en}.png`

- [ ] **Step 1: Create the driver `test_driver/integration_test.dart`** (writes screenshot bytes to files):
```dart
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final file = File('assets/screenshots/$name.png');
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    },
  );
}
```

- [ ] **Step 2: Create `integration_test/screenshots_test.dart`** that seeds data, pumps the real `HabbitsApp`, navigates, and captures. Use the in-memory DB + a no-op notification service so nothing external is touched. (Adjust import paths/finders to the actual widgets; read the screens first.)
```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:habbits/data/repositories/settings_repository.dart';
import 'package:habbits/data/services/database/database.dart';
import 'package:habbits/data/services/database/database_providers.dart';
import 'package:habbits/data/services/notification_service.dart';
import 'package:habbits/domain/dates.dart';
import 'package:habbits/main.dart';

class _NoopNotifications extends NotificationService {
  @override
  Future<void> init() async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> syncSchedule(List reminders, {required String body}) async {}
  @override
  Future<void> cancelAll() async {}
}

Future<AppDatabase> seededDb() async {
  final db = AppDatabase(NativeDatabase.memory());
  final dao = db.habitDao;
  final today = dateOnly(DateTime.now());
  Future<void> add(String name, int color, List<int> doneDaysAgo, String? reminder) async {
    final id = await dao.createHabit(name: name, color: color);
    if (reminder != null) await dao.setReminderTime(id, reminder);
    for (final d in doneDaysAgo) {
      await dao.toggleCompletion(id, today.subtract(Duration(days: d)));
    }
  }
  await add('Read', 0xFF009688, [0, 1, 2, 3, 5, 6, 8, 9], '21:00');
  await add('Exercise', 0xFFEF5350, [0, 1, 3, 4, 7, 10], '07:30');
  await add('Meditate', 0xFF7E57C2, [1, 2, 4, 6, 9, 12], null);
  await add('Drink water', 0xFF42A5F5, [0, 2, 3, 4, 5, 6, 7, 8], null);
  return db;
}

Future<void> pumpApp(WidgetTester tester, {required Map<String, Object> prefs}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final db = await seededDb();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      notificationServiceProvider.overrideWithValue(_NoopNotifications()),
      sharedPreferencesProvider.overrideWithValue(sp),
    ],
    child: const HabbitsApp(),
  ));
  await tester.pumpAndSettle();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture README screenshots', (tester) async {
    // English run: home, detail, settings(language picker)
    await pumpApp(tester, prefs: {});
    await binding.convertFlutterSurfaceToImage(); // required on iOS before takeScreenshot
    await tester.pumpAndSettle();
    await binding.takeScreenshot('home-en');

    await tester.tap(find.byKey(const Key('habit-card-0')).first.evaluate().isNotEmpty
        ? find.byKey(const Key('habit-card-0'))
        : find.text('Read'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('detail-en');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-tile')));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('settings-en');

    // Russian run: home
    await pumpApp(tester, prefs: {'locale': 'ru'});
    await tester.pumpAndSettle();
    await binding.takeScreenshot('home-ru');
  });
}
```
> Notes for the executor: read `habit_list_screen.dart` to use the right finder for "open the first habit's detail" (a card tap → `HabitDetailScreen`); the `habit-card-0` key may not exist — fall back to tapping the first habit's name text (`find.text('Read')`). `convertFlutterSurfaceToImage()` is called once; after it the surface is an image (fine — we only screenshot afterward). If a second `convertFlutterSurfaceToImage` on the re-pump throws "already converted", guard it / ignore.

- [ ] **Step 3: Run the driver against the iOS simulator**
```bash
export PATH="/opt/homebrew/bin:$PATH"
xcrun simctl bootstatus habbits_ios -b
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart \
  -d habbits_ios
ls -la assets/screenshots/
```
Expected: four PNGs written. If `flutter drive` errors on the iOS surface/screenshot, retry on Android: boot `habbits_test` (see the `android-integration-test-setup` memory) and use `-d emulator-5554`.

- [ ] **Step 4: Inspect the four PNGs** — open each and confirm: real text (not boxes), populated home (4 habits with streaks + day-strips), a heatmap on detail, the language picker open on settings, and Russian copy on `home-ru`. Re-run if any screen is wrong.

- [ ] **Step 5: Commit**
```bash
git add test_driver/integration_test.dart integration_test/screenshots_test.dart assets/screenshots
git commit -m "docs: add en/ru app screenshots + screenshot driver

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Write the README

**Files:** Create `README.md` (repo root).

- [ ] **Step 1: Create `README.md`**
```markdown
# Habbits

A **local-first, cross-platform habit tracker. Your data, on your device.**

[![CI](https://github.com/quotidianlabs/habbits/actions/workflows/ci.yml/badge.svg)](https://github.com/quotidianlabs/habbits/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter)

Habbits is a small, fast habit tracker built around two ideas: **you own your
data** (everything lives in an on-device SQLite database — no account, no
backend) and **deleting a habit is frictionless**. iOS + Android, English and
Russian.

| Home | Home (Русский) | Detail | Settings |
|---|---|---|---|
| ![Home](assets/screenshots/home-en.png) | ![Home RU](assets/screenshots/home-ru.png) | ![Detail](assets/screenshots/detail-en.png) | ![Settings](assets/screenshots/settings-en.png) |

## Features

- ✅ Daily check-off with current-streak tracking
- 📅 6-week heatmap + recent-days list with retroactive editing
- ⏰ Per-habit reminders (on-device local notifications)
- ↕️ Drag-to-reorder the home list
- 💾 JSON export / import — your data is portable
- 🌍 English + Russian, following the device locale with an in-app override
- 🎨 Material 3, light theme
- 📱 iOS and Android from one Flutter codebase

## Architecture

Layered MVVM with Riverpod: **UI** (views + per-feature view models) →
**domain** (pure functions + models) → **data** (repositories over a Drift
SQLite database, notifications, preferences). Generated code is committed.

The design and implementation history for every change lives in
[`planning/`](planning/) — see, e.g., the
[layered-architecture refactor](planning/changes/archive/2026-06-15.01-architecture-refactor/design.md)
and the [Russian-language support](planning/changes/archive/2026-06-14.04-russian-language/design.md).

## Getting started

Requires [Flutter 3.44.2](https://flutter.dev). Then:

```bash
flutter pub get
flutter run
```

Generated `*.g.dart` (Drift, Riverpod, l10n) is committed, so a normal run needs
no code generation. After changing `@riverpod`/Drift code, regenerate with
`dart run build_runner build --delete-conflicting-outputs`.

## Development

This repo uses [`just`](https://github.com/casey/just):

```bash
just lint    # dart format + flutter analyze
just test    # flutter test (115 unit/widget tests)
```

The integration flow runs on a device/emulator:
`flutter test integration_test/critical_flow_test.dart`.

## License

[MIT](LICENSE) © 2026 quotidianlabs
```

- [ ] **Step 2: Verify links + image paths resolve**
```bash
cd /Users/kevinsmith/src/habbits
for img in home-en home-ru detail-en settings-en; do test -f "assets/screenshots/$img.png" && echo "ok $img" || echo "MISSING $img"; done
test -f LICENSE && echo "ok LICENSE" || echo "MISSING LICENSE"
grep -oE 'planning/changes/archive/[^)]+design\.md' README.md | while read -r p; do test -f "$p" && echo "ok $p" || echo "BROKEN $p"; done
```
Expected: all `ok`, no MISSING/BROKEN.

- [ ] **Step 3: Commit**
```bash
git add README.md
git commit -m "docs: add project README

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Final verification

- [ ] **Step 1:** `export PATH="/opt/homebrew/bin:$PATH"; flutter analyze && flutter test` → clean + 115 (screenshots aren't bundled; the new integration test isn't in the unit run).
- [ ] **Step 2:** Confirm `assets/screenshots/` is NOT under `flutter: assets:` in `pubspec.yaml` (`grep -n "assets/screenshots" pubspec.yaml` → empty).
- [ ] **Step 3:** Done — finishes via `finishing-a-development-branch` (PR). The README renders on the GitHub PR with images + badges.

---

## Self-Review notes (for the executor)

- **Spec coverage:** MIT LICENSE (T1), four en/ru screenshots via integration-test driver (T2), README with badges/screenshots/features/architecture/getting-started/dev/license (T3), verification (T4).
- **Screenshots are the risk** — real-text rendering needs a device; iterate the finders/surface-capture until the four PNGs look right; Android emulator is the fallback device.
- **No app behavior change** — screenshots/driver are not bundled; unit suite stays 115.

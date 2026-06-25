# Meaningful 100% Coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Take hand-written-code line coverage from 84.3% to a meaningful 100% — every line that can run under `flutter test` is tested; the only exclusions are the production DB file-open glue — on off-the-shelf `coverde` tooling.

**Architecture:** Replace the bespoke `tool/coverage.py` with the Dart-native `coverde` CLI (`transform` to exclude, `check` to gate); move exclusions into a `coverde.yaml` preset; isolate the unrunnable production DB connection into its own glob-excluded file; then backfill characterization tests for every remaining uncovered line — including the notification and backup platform boundaries, covered by mocking their method channels (no new test dependency).

**Tech Stack:** Flutter 3.44.2, Dart, Drift (in-memory `NativeDatabase.memory()` for tests), Riverpod, `flutter_local_notifications` 22.0.1, `flutter_timezone` 5.1.0, `share_plus` 11.1.0, `file_picker` 8.3.7, `path_provider` 2.1.5, `coverde` (coverage CLI), `flutter_test`, `mocktail` (dev-only, no codegen).

## Global Constraints

- Flutter version floor: **3.44.2** (matches CI).
- No third-party coverage *service* (no Codecov/Coveralls) — `coverde` is a local Dart CLI.
- **One new dev dependency, `mocktail`** (no codegen) — for mocking the notification plugin + backup platform interfaces (Tasks 1, 6, 7). Do not add any other test dependency, and no `build_runner`-based mocking (`mockito`). The one static call without an injection seam (`FlutterTimezone.getLocalTimezone()`) still uses `flutter_test`'s built-in `setMockMethodCallHandler`.
- Generated Dart is never tested: `**/*.g.dart`, `**/*.freezed.dart`, `**/app_localizations*.dart` are always excluded.
- Committed generated code: after touching `@riverpod`/Drift sources run `dart run build_runner build --delete-conflicting-outputs`.
- Pre-commit gate is `just lint-ci` (check-only) on an **already-committed** tree, not `just lint` (which rewrites files in place).
- Test function arguments are annotated (`(WidgetTester tester)`, `(Ref ref)`).
- All imports at the top of the file.
- These are **characterization tests for existing behavior** — they should PASS on first run. The "verify it fails" TDD step is replaced by "run it, confirm PASS, and confirm the target line is now covered" via `just coverage`.
- The exclusion budget is the DB **connection + providers** (+ the `tables.dart` fallback) only. If a line proves genuinely unrunnable under `flutter test`, STOP and surface it for a ruling — do not silently exclude.

---

## Notes on the verified codebase surface (read once)

These were confirmed by reading the sources during planning. Where a step says "verify the key," it guards against a widget `Key` that planning inferred rather than read verbatim — confirm by reading the named file before running, and adjust the `find.byKey(...)` if it differs.

- **Existing fakes** the codebase already uses (mirror this style, do not add a mocking lib): `_FixedPermission extends NotificationPermission` (`test/ui/settings_screen_test.dart`), `_FixedCurrentDay extends CurrentDay` (`test/ui/habit_detail_screen_test.dart`), `_FakeNotificationService extends NotificationService` (`test/ui/core/reminder_coordinator_test.dart`).
- **`FlutterLocalNotificationsPlugin` cannot be subclassed or hand-faked** (private generative constructor) — but `mocktail`'s `Mock implements …` works (it implements the interface, no constructor call). It's injected via the `NotificationService([plugin])` seam (Task 7).
- **`HabitDao` seeding methods**: `createHabit({required String name, required int color}) → Future<int>`, `setReminderTime(int id, String? hhmm)`, `toggleCompletion(int habitId, DateTime date)`, `renameHabit(int id, String name)`, `setColor(int id, int color)`, `deleteHabit(int id)`, `reorderHabits(List<int> orderedIds)`, `importReplace(List<BackupHabit> data)`.
- **`HabitRepository` is already fully covered** — no repository pass-through task is needed.
- **`BackupFormatException`** lives in `lib/domain/models/backup_data.dart`; `decodeBackup` / `encodeBackup` / `buildBackup` live in `lib/domain/backup_codec.dart`.

---

## Task 1: Migrate coverage tooling to `coverde` (gate stays 80)

Switch the pipeline off `tool/coverage.py` + `very_good_coverage` + the PR-comment action and onto `coverde`, with the exclusion list living in `coverde.yaml`. Threshold stays at the current floor (80) during the backfill; Task 13 raises it to 100.

**Files:**
- Create: `coverde.yaml`
- Modify: `Justfile` (the `coverage` recipe, lines 19-22)
- Modify: `pubspec.yaml` (add `mocktail` to `dev_dependencies`)
- Modify: `.github/workflows/ci.yml` (lines 27-54: the `pull-requests: write` permission + the three coverage steps + the PR-comment step)
- Delete: `tool/coverage.py`

**Interfaces:**
- Produces: `just coverage` runs `flutter test --coverage` → `coverde transform` (preset `exclude-untestable`) → `coverde check ... 80`. Later tasks rely on `just coverage` as the single local gate command. `mocktail` is available to test files (Tasks 6, 7).

- [ ] **Step 1: Verify the `coverde` CLI surface and pin a version**

```bash
dart pub global activate coverde
coverde transform --help   # confirm --input / --output / --transformations preset=<name>
coverde check --help       # confirm `coverde check --input <file> <min>`
dart pub global list | grep coverde   # note the resolved version for CI pinning
```

If `coverde transform` has no `--output` flag in the resolved version, it edits in place — drop `--output` from the recipes below.

- [ ] **Step 1b: Add `mocktail` as a dev dependency**

```bash
flutter pub add --dev mocktail
```
Expected: `pubspec.yaml` gains `mocktail:` under `dev_dependencies` (resolves to ^1.0.x) and `flutter pub get` runs. Commit it with this task (it is the shared test tool for Tasks 6-7); no production code depends on it.

- [ ] **Step 2: Create `coverde.yaml`**

```yaml
# coverde.yaml — single home for coverage exclusions (see planning/changes/2026-06-25.02-coverage-100).
# Generated Dart is machine-written; the database connection/providers are the
# production file-open glue, unrunnable under `flutter test` and covered instead
# by the emulator integration test (integration_test/).
transformations:
  exclude-untestable:
    - type: skip-by-glob
      glob: "**/*.g.dart"
    - type: skip-by-glob
      glob: "**/*.freezed.dart"
    - type: skip-by-glob
      glob: "**/app_localizations*.dart"
    - type: skip-by-glob
      glob: "**/data/services/database/connection.dart"
    - type: skip-by-glob
      glob: "**/data/services/database/database_providers.dart"
```

> Note: `connection.dart` does not exist yet (Task 2 creates it). Listing it now is harmless — `skip-by-glob` on an absent file is a no-op.

- [ ] **Step 3: Replace the `Justfile` coverage recipe** (lines 19-22):

```makefile
# tests with coverage; excludes generated + DB glue, gates the % (matches CI)
coverage:
    flutter test --coverage
    coverde transform --input coverage/lcov.info --output coverage/lcov.info --transformations preset=exclude-untestable
    coverde check --input coverage/lcov.info 80
```

- [ ] **Step 4: Update CI** — in `.github/workflows/ci.yml`, remove the `pull-requests: write` permission line (the PR comment is gone), and replace the three coverage steps ("Run tests with coverage", "Filter + summarize coverage", "Enforce coverage threshold") **and** the "Coverage comment on PR" step with:

```yaml
      - name: Run tests with coverage
        run: flutter test --coverage
      - name: Install coverde
        run: dart pub global activate coverde 0.3.0   # pin to the version resolved in Step 1
      - name: Filter generated + glue, enforce threshold
        run: |
          export PATH="$PATH":"$HOME/.pub-cache/bin"
          coverde transform --input coverage/lcov.info --output coverage/lcov.info --transformations preset=exclude-untestable
          coverde check --input coverage/lcov.info 80
```

> Replace `0.3.0` with the exact version from Step 1. The `permissions:` block should then read only `contents: read`.

- [ ] **Step 5: Delete the Python script**

```bash
git rm tool/coverage.py
```

- [ ] **Step 6: Run the new pipeline, confirm green**

```bash
just coverage
```
Expected: tests pass; `coverde check ... 80` prints a passing percentage (≥ the prior 84.3%, slightly higher now that the glue files are about to be excluded).

- [ ] **Step 7: Lint + commit**

```bash
just lint-ci
git add coverde.yaml Justfile pubspec.yaml pubspec.lock .github/workflows/ci.yml
git commit -m "ci: replace coverage.py + very_good_coverage with coverde; add mocktail

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Isolate the production DB connection

Move the unrunnable `driftDatabase(name: 'habbits')` file-open into `connection.dart` (already matched by the Task 1 exclusion glob). The in-memory test branch stays in `database.dart` and stays measured.

**Files:**
- Create: `lib/data/services/database/connection.dart`
- Modify: `lib/data/services/database/database.dart` (imports + constructor, lines 1-41)

**Interfaces:**
- Produces: `QueryExecutor openConnection()` in `connection.dart`; `AppDatabase`'s no-executor branch calls it.

- [ ] **Step 1: Create `connection.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Opens the on-device SQLite database file. This is production I/O glue: it
/// cannot run under `flutter test` (no app-documents directory), so it is
/// excluded from unit coverage (see coverde.yaml) and exercised by the emulator
/// integration test instead.
QueryExecutor openConnection() => driftDatabase(name: 'habbits');
```

- [ ] **Step 2: Modify `database.dart`** — replace the top imports so `drift_flutter` moves to `connection.dart`:

```dart
import 'package:drift/drift.dart';

import 'connection.dart';
import 'habit_dao.dart';

part 'database.g.dart';
```

and change the production branch of the constructor (currently line 40 `: driftDatabase(name: 'habbits'),`) to delegate:

```dart
  AppDatabase([QueryExecutor? executor])
    : super(
        executor != null
            // When an explicit executor is provided (typically in tests),
            // enable synchronous stream closing so that Flutter's fake-async
            // environment doesn't see a pending 0-duration timer after the
            // last stream listener detaches on widget disposal.
            ? DatabaseConnection(executor, closeStreamsSynchronously: true)
            : openConnection(),
      );
```

- [ ] **Step 3: Regenerate, run DAO tests, confirm green**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/data/services/database/
```
Expected: PASS — the in-memory branch is unchanged.

- [ ] **Step 4: Confirm coverage still green**

```bash
just coverage
```
Expected: PASS; `connection.dart` does not appear in the report (excluded).

- [ ] **Step 5: Lint + commit**

```bash
just lint-ci
git add lib/data/services/database/connection.dart lib/data/services/database/database.dart lib/data/services/database/database.g.dart
git commit -m "refactor(db): isolate production connection into connection.dart

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Cover (or, as fallback, exclude) the Drift table getters

`database.dart:8-26` are the `Habits` / `Completions` column getters. They execute when the schema is created. Add a schema-creation test and check whether it covers them; if Drift still credits them to generated code, move the tables to `tables.dart` and exclude that file.

**Files:**
- Create: `test/data/services/database/schema_test.dart`
- (Fallback) Create: `lib/data/services/database/tables.dart`; Modify: `lib/data/services/database/database.dart`, `coverde.yaml`

**Interfaces:**
- Consumes: `AppDatabase(NativeDatabase.memory())`.

- [ ] **Step 1: Write the schema-creation test**

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/services/database/database.dart';

void main() {
  test('schema creates the habits and completions tables', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // Forcing a query opens the connection and runs migration.onCreate,
    // which builds every table from its column definitions.
    final habits = await db.select(db.habits).get();
    final completions = await db.select(db.completions).get();

    expect(habits, isEmpty);
    expect(completions, isEmpty);
    // The generated table metadata reflects the hand-written column getters.
    expect(db.habits.actualTableName, 'habits');
    expect(db.completions.actualTableName, 'completions');
  });
}
```

- [ ] **Step 2: Run it and inspect coverage of `database.dart:8-26`**

```bash
flutter test test/data/services/database/schema_test.dart
flutter test --coverage
coverde transform --input coverage/lcov.info --output coverage/lcov.info --transformations preset=exclude-untestable
grep -A40 'database.dart' coverage/lcov.info | grep -E '^DA:(8|9|1[0-9]|2[0-6]),0$' || echo "GETTERS COVERED"
```
If it prints `GETTERS COVERED`, skip Step 3 — go to Step 4.

- [ ] **Step 3 (fallback only — if getters still show `,0`): move tables out and exclude**

Create `lib/data/services/database/tables.dart`:

```dart
import 'package:drift/drift.dart';

class Habits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get color => integer()();
  TextColumn get reminderTime => text().nullable()(); // 'HH:mm', null = none
  IntColumn get sortOrder => integer()();
  DateTimeColumn get createdAt => dateTime()();
}

class Completions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get habitId =>
      integer().references(Habits, #id, onDelete: KeyAction.cascade)();
  TextColumn get localDate => text()(); // 'YYYY-MM-DD'
  DateTimeColumn get createdAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {habitId, localDate},
  ];
}
```

In `database.dart`, delete the two table classes and add `import 'tables.dart';`. Add to `coverde.yaml` under `exclude-untestable`:

```yaml
    - type: skip-by-glob
      glob: "**/data/services/database/tables.dart"
```

Then `dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 4: Confirm green**

```bash
just lint-ci && just coverage
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "test(db): schema-creation test covers table definitions

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: SharedPreferences provider unimplemented guard

Covers `settings_repository.dart` lines 7-8 — reading `sharedPreferencesProvider` without an override throws `UnimplementedError`.

**Files:**
- Modify: `test/data/repositories/settings_repository_test.dart` (append a test + add one import)

- [ ] **Step 1: Add imports + test**

At the top, add (alongside the existing imports):
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
```

Inside `main`, append:
```dart
  test('sharedPreferencesProvider throws until overridden in main', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(sharedPreferencesProvider),
      throwsA(isA<UnimplementedError>()),
    );
  });
```

- [ ] **Step 2: Run + confirm pass**

```bash
flutter test test/data/repositories/settings_repository_test.dart
```
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add test/data/repositories/settings_repository_test.dart
git commit -m "test(settings): cover sharedPreferencesProvider unimplemented guard

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: backup_codec invalid-field edge cases + exception toString

Covers `backup_codec.dart` 76 (invalid color), 80 (invalid sortOrder), 89 (invalid createdAt), 93-95 (invalid completions list), and `backup_data.dart` 35-36 (`BackupFormatException.toString`).

**Files:**
- Modify: `test/domain/backup_codec_test.dart` (extend the existing `decodeBackup rejects invalid input` group + add a toString test)

**Interfaces:**
- Consumes: `decodeBackup(String) → BackupData` (throws `BackupFormatException`), `BackupFormatException(String message)`.

- [ ] **Step 1: Inspect the exact JSON shape the codec expects**

Read `lib/domain/backup_codec.dart` `decodeBackup` (lines ~32-95) to confirm the top-level marker/version keys and the per-habit field names (`name`, `color`, `sortOrder`, `createdAt`, `completions`). Build each malformed input from a minimal valid habit map with exactly one field corrupted.

- [ ] **Step 2: Add the rejection cases** — inside the existing `group('decodeBackup rejects invalid input', ...)`, using its `expectReject(String src)` helper. Construct each `src` as a valid backup JSON string with one field made the wrong type (e.g. `"color": "red"` for line 76, `"sortOrder": "x"` for 80, `"createdAt": "not-a-date"` for 89, `"completions": 5` for 93-95). Match the real top-level structure read in Step 1. Then assert each rejects:

```dart
    expectReject(_validBackupWith(color: '"red"'));        // line 76
    expectReject(_validBackupWith(sortOrder: '"x"'));      // line 80
    expectReject(_validBackupWith(createdAt: '"nope"'));   // line 89
    expectReject(_validBackupWith(completions: '5'));      // lines 93-95
```

Add a small string-builder helper near the top of the test file that emits a valid backup JSON with the named field overridden (mirror the exact key names + app marker / version from Step 1):

```dart
  // Emits a valid single-habit backup JSON, overriding one field's raw value.
  String _validBackupWith({
    String color = '1',
    String sortOrder = '0',
    String createdAt = '"2026-06-01T08:00:00.000"',
    String completions = '[]',
  }) =>
      '{"<APP_MARKER_KEY>":"<APP_MARKER_VALUE>","version":1,'
      '"exportedAt":"2026-06-14T09:00:00.000","habits":[{'
      '"name":"Read","color":$color,"reminderTime":null,'
      '"sortOrder":$sortOrder,"createdAt":$createdAt,'
      '"completions":$completions}]}';
```

> Replace `<APP_MARKER_KEY>`/`<APP_MARKER_VALUE>` and confirm the field key names against `decodeBackup` (Step 1) — the existing passing round-trip test in this file shows the canonical shape.

- [ ] **Step 3: Add the `toString` test** — append in `main`:

```dart
  test('BackupFormatException.toString includes the message', () {
    const e = BackupFormatException('bad file');
    expect(e.toString(), 'BackupFormatException: bad file');
  });
```

Add `import 'package:habbits/domain/models/backup_data.dart';` if not already imported.

- [ ] **Step 4: Run + confirm pass**

```bash
flutter test test/domain/backup_codec_test.dart
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add test/domain/backup_codec_test.dart
git commit -m "test(backup): cover codec invalid-field branches + exception toString

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: BackupRepository export/import via platform-interface fakes

Covers `backup_repository.dart` 17, 23-30 (`exportAndShare`), 36-40, 44, 46 (`pickAndDecode`, including the null-cancel branch). No file exclusions — the plugins' platform interfaces are swapped for fakes.

**Files:**
- Create: `test/data/repositories/backup_repository_test.dart`

**Interfaces:**
- Consumes: `BackupRepository(HabitRepository)`; `HabitRepository(db.habitDao)`; `PathProviderPlatform.instance`, `SharePlatform.instance`, `FilePicker.platform`.

- [ ] **Step 1: Confirm the platform-interface seams**

Read the three plugin packages' platform interfaces to confirm the override points and the method each call dispatches to (stable, but verify the names):
- `path_provider_platform_interface` → `PathProviderPlatform.instance`, method `getTemporaryPath()`.
- `share_plus_platform_interface` → `SharePlatform.instance`, method `share(ShareParams)` (what `SharePlus.instance.share(...)` dispatches to). Note the `ShareResult` / `ShareResultStatus` / `ShareParams.files`/`.subject` shapes.
- `file_picker` → `FilePicker.platform`, method `pickFiles(...)` returning `FilePickerResult?`.

Each mock is a `mocktail` mock with `MockPlatformInterfaceMixin` so the platform-interface token check passes: `class _MockX extends Mock with MockPlatformInterfaceMixin implements X {}`.

- [ ] **Step 2: Write the tests**

```dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/repositories/backup_repository.dart';
import 'package:habbits/data/repositories/habit_repository.dart';
import 'package:habbits/data/services/database/database.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

class _MockPathProvider extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {}

class _MockShare extends Mock
    with MockPlatformInterfaceMixin
    implements SharePlatform {}

class _MockFilePicker extends Mock
    with MockPlatformInterfaceMixin
    implements FilePicker {}

class _FakeShareParams extends Fake implements ShareParams {}

void main() {
  late AppDatabase db;
  late BackupRepository repo;
  late _MockShare share;

  setUpAll(() => registerFallbackValue(_FakeShareParams()));

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = BackupRepository(HabitRepository(db.habitDao));

    final paths = _MockPathProvider();
    when(() => paths.getTemporaryPath()).thenAnswer((_) async => Directory.systemTemp.path);
    PathProviderPlatform.instance = paths;

    share = _MockShare();
    when(() => share.share(any())).thenAnswer(
      (_) async => const ShareResult('ok', ShareResultStatus.success),
    );
    SharePlatform.instance = share;
  });
  tearDown(() => db.close());

  test('exportAndShare writes a temp file and opens the share sheet', () async {
    await db.habitDao.createHabit(name: 'Read', color: 1);

    await repo.exportAndShare(subject: 'My backup');

    final captured =
        verify(() => share.share(captureAny())).captured.single as ShareParams;
    expect(captured.subject, 'My backup');
    expect(captured.files, hasLength(1));
    final written = File(captured.files!.single.path);
    expect(await written.exists(), isTrue);
    expect(await written.readAsString(), contains('Read'));
  });

  test('pickAndDecode returns null when the user cancels', () async {
    final picker = _MockFilePicker();
    when(() => picker.pickFiles(allowMultiple: any(named: 'allowMultiple')))
        .thenAnswer((_) async => null);
    FilePicker.platform = picker;

    expect(await repo.pickAndDecode(), isNull);
  });

  test('pickAndDecode decodes the chosen backup file', () async {
    // Round-trip a real export to disk, then pick it back.
    await db.habitDao.createHabit(name: 'Read', color: 1);
    await repo.exportAndShare(subject: 's');
    final path =
        (verify(() => share.share(captureAny())).captured.single as ShareParams)
            .files!
            .single
            .path;

    final picker = _MockFilePicker();
    when(() => picker.pickFiles(allowMultiple: any(named: 'allowMultiple')))
        .thenAnswer(
      (_) async => FilePickerResult([PlatformFile(path: path, name: 'b.json', size: 0)]),
    );
    FilePicker.platform = picker;

    final data = await repo.pickAndDecode();

    expect(data, isNotNull);
    expect(data!.habits.single.name, 'Read');
  });
}
```

> Confirm against Step 1: the `pickFiles` named param the production code passes (`allowMultiple: false`) — mocktail matches on the named args you stub, so stubbing just `allowMultiple` is enough only if no other named arg is passed positionally; if production passes more, add matching `any(named: ...)` stubs or stub `pickFiles()` with no args constraint. Confirm `ShareResult` / `ShareResultStatus` constructor arity and `ShareParams.files`/`.subject` against `share_plus_platform_interface`.

- [ ] **Step 3: Run + confirm pass**

```bash
flutter test test/data/repositories/backup_repository_test.dart
```
Expected: PASS (3 tests).

- [ ] **Step 4: Commit**

```bash
git add test/data/repositories/backup_repository_test.dart
git commit -m "test(backup): cover export/import via mocked plugin platform interfaces

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: NotificationService coverage via injected mocktail plugin

Covers `notification_service.dart` `init` (34-56), `refreshTimeZone` (60-64), `hasPermission` (73-86, both platform branches), `requestPermission` (89-101, both branches), `syncSchedule` (104-130), `cancelAll` (132), and `scheduledInstant` (already partly tested). A `mocktail` mock of `FlutterLocalNotificationsPlugin` is injected via the constructor seam, so the platform branches are reached by stubbing the resolver — no `debugDefaultTargetPlatformOverride`, no channel-reply-shape guessing. Only the static `FlutterTimezone.getLocalTimezone()` (no seam) is covered with a `flutter_timezone` channel mock.

**Files:**
- Modify: `test/data/services/notification_service_test.dart` (it already covers `scheduledInstant` and sets up `tzdata`/`tz.local` in `setUpAll`)

**Interfaces:**
- Consumes: `NotificationService([FlutterLocalNotificationsPlugin])` (inject the mock); its public methods; `ScheduledReminder(habitName, when)` from `lib/domain/reminder_schedule.dart`.

- [ ] **Step 1: Confirm the plugin method signatures**

Read `~/.pub-cache/hosted/pub.dev/flutter_local_notifications-22.0.1/lib/flutter_local_notifications.dart` (+ the platform-specific files) to confirm the exact signatures the mock must stub:
- `Future<bool?> initialize(InitializationSettings settings, {...})` — confirm whether `settings` is positional or named (the production code calls `initialize(settings: const InitializationSettings(...))`, i.e. named in v22).
- `Future<void> cancelAll()`, `Future<void> zonedSchedule({required int id, String? title, String? body, required TZDateTime scheduledDate, required NotificationDetails notificationDetails, required AndroidScheduleMode androidScheduleMode, ...})`.
- `T? resolvePlatformSpecificImplementation<T extends FlutterLocalNotificationsPlatform>()`.
- `AndroidFlutterLocalNotificationsPlugin`: `createNotificationChannel(AndroidNotificationChannel)`, `areNotificationsEnabled()`, `requestNotificationsPermission()`.
- `IOSFlutterLocalNotificationsPlugin`: `checkPermissions()` (returns `NotificationsEnabledOptions`, which has an `isEnabled` getter), `requestPermissions({bool? alert, bool? badge, bool? sound, ...})`.

Also confirm the `flutter_timezone` channel name + `getLocalTimezone` reply shape:
```bash
grep -rn "MethodChannel(" ~/.pub-cache/hosted/pub.dev/flutter_timezone-5.1.0/lib/
```

- [ ] **Step 2: Add the mocks + fallbacks** — at the top of the file, declare the mocks and register fallbacks (mocktail needs a fallback for every non-nullable type used with `any()`):

```dart
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mocktail/mocktail.dart';
import 'package:habbits/data/services/notification_service.dart';
import 'package:habbits/domain/reminder_schedule.dart';

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}
class _MockAndroid extends Mock implements AndroidFlutterLocalNotificationsPlugin {}
class _MockIOS extends Mock implements IOSFlutterLocalNotificationsPlugin {}
class _MockEnabledOptions extends Mock implements NotificationsEnabledOptions {}
```

In the existing `setUpAll` (after `tzdata.initializeTimeZones()` + `tz.setLocalLocation(...)`), register fallbacks:

```dart
    registerFallbackValue(const InitializationSettings());
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(const AndroidNotificationChannel('x', 'x'));
    registerFallbackValue(AndroidScheduleMode.inexactAllowWhileIdle);
    registerFallbackValue(tz.TZDateTime(tz.local, 2026));
```

> `InitializationSettings()` and `NotificationDetails()` have all-optional constructors (verify in Step 1); `AndroidNotificationChannel(id, name)` needs two positional args. If any `any()` call later errors with "no fallback registered for X", add that type here.

- [ ] **Step 3: Android-branch tests (`init`, `hasPermission`, `requestPermission`, `syncSchedule`, `cancelAll`)**

```dart
  group('android plugin boundary', () {
    late _MockPlugin plugin;
    late _MockAndroid android;

    setUp(() {
      plugin = _MockPlugin();
      android = _MockAndroid();
      // Android present, iOS absent → android branch.
      when(() => plugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>())
          .thenReturn(android);
      when(() => plugin
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>())
          .thenReturn(null);
    });

    test('init initializes the plugin and creates the channel', () async {
      mockTimezone('America/New_York'); // helper from Step 5
      when(() => plugin.initialize(settings: any(named: 'settings')))
          .thenAnswer((_) async => true);
      when(() => android.createNotificationChannel(any()))
          .thenAnswer((_) async {});

      await NotificationService(plugin).init();

      verify(() => plugin.initialize(settings: any(named: 'settings'))).called(1);
      verify(() => android.createNotificationChannel(any())).called(1);
    });

    test('hasPermission reads areNotificationsEnabled', () async {
      when(() => android.areNotificationsEnabled()).thenAnswer((_) async => true);
      expect(await NotificationService(plugin).hasPermission(), isTrue);
    });

    test('requestPermission requests the android permission', () async {
      when(() => android.requestNotificationsPermission())
          .thenAnswer((_) async => true);
      expect(await NotificationService(plugin).requestPermission(), isTrue);
    });

    test('syncSchedule cancels all then schedules one per reminder', () async {
      when(() => plugin.cancelAll()).thenAnswer((_) async {});
      when(() => plugin.zonedSchedule(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: any(named: 'androidScheduleMode'),
          )).thenAnswer((_) async {});

      await NotificationService(plugin).syncSchedule(
        [
          ScheduledReminder(habitName: 'Read', when: DateTime(2026, 6, 25, 20)),
          ScheduledReminder(habitName: 'Walk', when: DateTime(2026, 6, 25, 21)),
        ],
        body: 'time!',
      );

      verifyInOrder([
        () => plugin.cancelAll(),
        () => plugin.zonedSchedule(
              id: any(named: 'id'),
              title: any(named: 'title'),
              body: any(named: 'body'),
              scheduledDate: any(named: 'scheduledDate'),
              notificationDetails: any(named: 'notificationDetails'),
              androidScheduleMode: any(named: 'androidScheduleMode'),
            ),
      ]);
      verify(() => plugin.zonedSchedule(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: any(named: 'androidScheduleMode'),
          )).called(2);
    });

    test('cancelAll cancels everything', () async {
      when(() => plugin.cancelAll()).thenAnswer((_) async {});
      await NotificationService(plugin).cancelAll();
      verify(() => plugin.cancelAll()).called(1);
    });
  });
```

> Confirm `ScheduledReminder`'s field names against `lib/domain/reminder_schedule.dart` (planning saw `habitName` / `when`). If `initialize`'s `settings` is positional rather than named (Step 1), stub `plugin.initialize(any())` instead.

- [ ] **Step 4: iOS-branch tests (`hasPermission`, `requestPermission`)** — cover the `ios != null` paths (73-79, 89-94):

```dart
  group('ios plugin boundary', () {
    late _MockPlugin plugin;
    late _MockIOS ios;

    setUp(() {
      plugin = _MockPlugin();
      ios = _MockIOS();
      when(() => plugin
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>())
          .thenReturn(ios);
    });

    test('hasPermission returns the ios isEnabled', () async {
      final opts = _MockEnabledOptions();
      when(() => opts.isEnabled).thenReturn(true);
      when(() => ios.checkPermissions()).thenAnswer((_) async => opts);

      expect(await NotificationService(plugin).hasPermission(), isTrue);
    });

    test('requestPermission requests the ios permissions', () async {
      when(() => ios.requestPermissions(
            alert: any(named: 'alert'),
            badge: any(named: 'badge'),
            sound: any(named: 'sound'),
          )).thenAnswer((_) async => true);

      expect(await NotificationService(plugin).requestPermission(), isTrue);
    });
  });
```

> Mocking `NotificationsEnabledOptions` and stubbing its `isEnabled` getter avoids needing its constructor signature. Confirm `requestPermissions`' named params from Step 1; if it takes more, add matching `any(named: ...)` entries.

- [ ] **Step 5: `refreshTimeZone` test + timezone channel helper**

Add a small helper near the harness (the one static call with no injection seam):

```dart
  void mockTimezone(String id) {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'), // confirm name in Step 1
      (call) async => id, // reply shape per Step 1 (String id, or a map)
    );
  }
```

```dart
  test('refreshTimeZone resolves the device zone into tz.local', () async {
    mockTimezone('Europe/Moscow');
    await NotificationService(_MockPlugin()).refreshTimeZone();
    expect(tz.local.name, 'Europe/Moscow');
  });
```

> `tz` is already imported in this file (`as tz`) and `tzdata.initializeTimeZones()` runs in the existing `setUpAll`. If `getLocalTimezone`'s reply is a map (e.g. `{'identifier': id}`) rather than a bare String, return that shape from `mockTimezone`. Add a `tearDown` that clears the handler: `...setMockMethodCallHandler(const MethodChannel('flutter_timezone'), null);`.

- [ ] **Step 6: Run, confirm pass, and confirm the lines are covered**

```bash
flutter test test/data/services/notification_service_test.dart
just coverage
```
Expected: PASS; `notification_service.dart` reports 0 uncovered lines. If a single line remains uncovered and is provably unrunnable under `flutter test`, STOP and surface it (do not exclude without a ruling).

- [ ] **Step 7: Commit**

```bash
git add test/data/services/notification_service_test.dart
git commit -m "test(notifications): cover the plugin boundary via an injected mocktail plugin

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: CurrentDayTicker widget test

Covers `current_day.dart` `CurrentDay.refresh` (22-24) and `CurrentDayTicker` (32-69): the midnight `Timer` re-arm, the resume refresh, and dispose.

**Files:**
- Modify: `test/ui/core/current_day_test.dart`

**Interfaces:**
- Consumes: `CurrentDayTicker(child:)`, `currentDayProvider`, `nextLocalMidnight` (via the ticker).

- [ ] **Step 1: Read the existing test** — `test/ui/core/current_day_test.dart` to reuse its `ProviderScope`/read pattern and confirm what `CurrentDay.refresh` coverage it already has (it likely tests the notifier directly; the uncovered lines are the `CurrentDayTicker` State).

- [ ] **Step 2: Add the ticker widget test**

```dart
  testWidgets('ticker refreshes currentDay across the midnight timer', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CurrentDayTicker(child: SizedBox())),
      ),
    );

    // Arming reads currentDay; advancing past the next-midnight Timer fires
    // _refresh + re-arms. Pump just over 24h to guarantee the timer elapses.
    await tester.pump(const Duration(hours: 25));
    await tester.pumpAndSettle();

    expect(container.read(currentDayProvider), isA<DateTime>());

    // Resume path: dispatch a resume lifecycle event, which calls _refresh.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    // Dispose path: replacing the tree disposes the State (cancels timer +
    // lifecycle listener).
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SizedBox()),
      ),
    );
    expect(tester.takeException(), isNull);
  });
```

Add imports as needed:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/ui/core/current_day.dart';
```

> `AppLifecycleListener(onResume:)` responds to the resumed transition; pumping a paused→resumed sequence is the documented way to drive it. If `onResume` doesn't fire from `handleAppLifecycleStateChanged` in this Flutter version, drive it via `tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed)` alone after an `inactive`/`paused` step — confirm `_refresh` ran by checking the provider didn't throw.

- [ ] **Step 3: Run + confirm pass + coverage**

```bash
flutter test test/ui/core/current_day_test.dart
just coverage
```
Expected: PASS; `current_day.dart` at 100%.

- [ ] **Step 4: Commit**

```bash
git add test/ui/core/current_day_test.dart
git commit -m "test(ui): cover CurrentDayTicker timer, resume, and dispose

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: habit_dialogs + recent_days_list edge paths

Covers `habit_dialogs.dart` 61 (empty-name pop), 81 (TextField `onSubmitted`), 116 (delete cancel), 140 (delete confirm); and `recent_days_list.dart` 51 (checkbox `onChanged` → `onToggle`).

**Files:**
- Modify: `test/ui/habit_dialogs_test.dart`
- Modify: `test/ui/recent_days_list_test.dart`

**Interfaces:**
- Consumes: `showHabitNameDialog(context, ...)`, `confirmDeleteHabit(context, name) → Future<bool>`, `RecentDaysList(completed, today, count, onToggle)`.

- [ ] **Step 1: Read both source files** to confirm the widget keys: in `lib/ui/widgets/habit_dialogs.dart` the name-field key, the confirm/cancel button keys (planning saw `habit-name-field`, `habit-name-confirm`, `confirm-delete`); in `lib/ui/widgets/recent_days_list.dart` the per-day key (`ValueKey('daylist-<iso>')`) and that the `Checkbox.onChanged` calls `onToggle(day.date)`. Confirm the English strings via `lib/l10n/app_localizations_en.dart` (`cancel`, `delete`).

- [ ] **Step 2: habit_dialogs — add the three paths** (mirror the file's existing `open`-button harness):

```dart
  testWidgets('submitting an empty name pops without a result', (tester) async {
    HabitFormResult? result;
    var popped = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open'),
              onPressed: () async {
                result = await showHabitNameDialog(context);
                popped = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    // Leave the name field empty and confirm → early Navigator.pop (line 61).
    await tester.tap(find.byKey(const Key('habit-name-confirm')));
    await tester.pumpAndSettle();

    expect(popped, isTrue);
    expect(result, isNull);
  });

  testWidgets('pressing done on the name field submits (onSubmitted)', (
    tester,
  ) async {
    HabitFormResult? result;
    await tester.pumpWidget(/* same host as above, capturing result */);
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('habit-name-field')), 'Run');
    await tester.testTextInput.receiveAction(TextInputAction.done); // line 81
    await tester.pumpAndSettle();

    expect(result?.name, 'Run');
  });

  testWidgets('confirmDeleteHabit returns false on cancel, true on confirm', (
    tester,
  ) async {
    final results = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open'),
              onPressed: () async =>
                  results.add(await confirmDeleteHabit(context, 'Read')),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel')); // l10n.cancel → line 116
    await tester.pumpAndSettle();
    expect(results.single, isFalse);

    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete'))); // line 140
    await tester.pumpAndSettle();
    expect(results.last, isTrue);
  });
```

> Repeat the full `host` widget in the `onSubmitted` test (don't reference "same as above" in the real code — paste it). Confirm `HabitFormResult`'s `name` field and the three keys from Step 1.

- [ ] **Step 3: recent_days_list — add the toggle test** (mirror the file's `host(...)` helper):

```dart
  testWidgets('tapping a day checkbox invokes onToggle with that date', (
    tester,
  ) async {
    DateTime? toggled;
    await tester.pumpWidget(host(onToggle: (d) => toggled = d));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first); // onChanged → line 51
    await tester.pumpAndSettle();

    expect(toggled, isNotNull);
  });
```

- [ ] **Step 4: Run + confirm pass + coverage**

```bash
flutter test test/ui/habit_dialogs_test.dart test/ui/recent_days_list_test.dart
just coverage
```
Expected: PASS; both files at 100%.

- [ ] **Step 5: Commit**

```bash
git add test/ui/habit_dialogs_test.dart test/ui/recent_days_list_test.dart
git commit -m "test(ui): cover dialog empty-submit/delete paths + day-toggle callback

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: SettingsScreen export/import flows + SettingsViewModel delegates

Covers `settings_screen.dart` 74, 81 (export/import onTap), 112-125 (`_export` incl. error SnackBar), 127-149 (`_import` incl. format/read errors), 167-186 (`confirmAndImport`), and `settings_view_model.dart` 16-17 (`export`) + 21-22 (`pickImport`) — exercised end-to-end through the screen with `backupRepositoryProvider` overridden by a fake.

**Files:**
- Modify: `test/ui/settings_screen_test.dart`

**Interfaces:**
- Consumes: the file's existing `settingsApp(db, prefs)` helper + `_prefs()`; `backupRepositoryProvider`; `BackupRepository`; `BackupData`; `BackupFormatException`.

- [ ] **Step 1: Read `settings_screen.dart`** (74-186) to confirm the keys (`export-data`, `import-data`, `confirm-import`) and which `l10n` strings each error/success SnackBar shows (`exportFailed`, `invalidBackupFile`, `couldntReadFile`, `importFailed`, `importedHabits`). Confirm `settingsViewModelProvider` method names (`export`, `pickImport`, `applyImport`) and `backupRepositoryProvider` from `lib/data/repositories/backup_repository.dart`.

- [ ] **Step 2: Add a fake BackupRepository + override helper** at the top of the test file:

```dart
class _FakeBackup extends BackupRepository {
  _FakeBackup(super.habits, {this.exportThrows = false, this.picked, this.pickThrows});
  final bool exportThrows;
  final BackupData? picked;
  final Object? pickThrows;
  bool exported = false;

  @override
  Future<void> exportAndShare({required String subject}) async {
    if (exportThrows) throw Exception('share failed');
    exported = true;
  }

  @override
  Future<BackupData?> pickAndDecode() async {
    if (pickThrows != null) throw pickThrows!;
    return picked;
  }
}
```

`BackupRepository`'s constructor takes a `HabitRepository`; build a real one over the in-memory db (`HabitRepository(db.habitDao)`), so `super(...)` is satisfied. Add a helper that pumps `SettingsScreen` with `backupRepositoryProvider` overridden:

```dart
Widget settingsAppWithBackup(
  AppDatabase db,
  SharedPreferences prefs,
  BackupRepository backup,
) => ProviderScope(
  overrides: [
    appDatabaseProvider.overrideWithValue(db),
    sharedPreferencesProvider.overrideWithValue(prefs),
    backupRepositoryProvider.overrideWithValue(backup),
  ],
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: SettingsScreen(),
  ),
);
```

Add imports: `backup_repository.dart`, `habit_repository.dart`, `backup_data.dart` (for `BackupData`/`BackupHabit`/`BackupFormatException`).

- [ ] **Step 3: Add the flow tests**

```dart
  testWidgets('tapping Export delegates to the backup repository', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final backup = _FakeBackup(HabitRepository(db.habitDao));
    await tester.pumpWidget(settingsAppWithBackup(db, await _prefs(), backup));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('export-data'))); // line 74 → _export
    await tester.pumpAndSettle();

    expect(backup.exported, isTrue);
  });

  testWidgets('export failure shows the error SnackBar', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final backup = _FakeBackup(HabitRepository(db.habitDao), exportThrows: true);
    await tester.pumpWidget(settingsAppWithBackup(db, await _prefs(), backup));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('export-data')));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget); // l10n.exportFailed (lines 119-122)
  });

  testWidgets('import of a malformed file shows invalid-backup SnackBar', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final backup = _FakeBackup(
      HabitRepository(db.habitDao),
      pickThrows: const BackupFormatException('bad'),
    );
    await tester.pumpWidget(settingsAppWithBackup(db, await _prefs(), backup));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('import-data'))); // line 81 → _import
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget); // l10n.invalidBackupFile
  });

  testWidgets('import read error shows couldnt-read SnackBar', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final backup =
        _FakeBackup(HabitRepository(db.habitDao), pickThrows: Exception('io'));
    await tester.pumpWidget(settingsAppWithBackup(db, await _prefs(), backup));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('import-data')));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget); // l10n.couldntReadFile
  });

  testWidgets('import success confirms then applies, showing imported count', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final data = BackupData(
      version: 1,
      exportedAt: DateTime(2026, 6, 14),
      habits: [
        BackupHabit(
          name: 'Read',
          color: 1,
          reminderTime: null,
          sortOrder: 0,
          createdAt: DateTime(2026, 6, 1),
          completions: const [],
        ),
      ],
    );
    final backup = _FakeBackup(HabitRepository(db.habitDao), picked: data);
    await tester.pumpWidget(settingsAppWithBackup(db, await _prefs(), backup));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('import-data')));
    await tester.pumpAndSettle();
    // Confirm the replace dialog (line 178 → applyImport).
    await tester.tap(find.byKey(const Key('confirm-import')));
    await tester.pumpAndSettle();

    // Applied through the real HabitRepository → the habit now exists.
    expect((await db.habitDao.getHabitsWithDates()).single.habit.name, 'Read');
    expect(find.byType(SnackBar), findsOneWidget); // l10n.importedHabits(1)
  });
```

> Confirm `BackupData`/`BackupHabit` field names against `lib/domain/models/backup_data.dart` (planning saw `version`, `exportedAt`, `habits`; habit: `name`, `color`, `reminderTime`, `sortOrder`, `createdAt`, `completions`). Confirm the `confirm-import` key and that `applyImport` calls `importReplace` on the repo (so the in-memory DB ends with the habit). If `applyImport` reads through `backupRepositoryProvider` rather than `habitRepositoryProvider`, assert on `find.byType(SnackBar)` for the success string instead of the DB row.

- [ ] **Step 4: Run + confirm pass + coverage**

```bash
flutter test test/ui/settings_screen_test.dart
just coverage
```
Expected: PASS; `settings_screen.dart` + `settings_view_model.dart` at 100%.

- [ ] **Step 5: Commit**

```bash
git add test/ui/settings_screen_test.dart
git commit -m "test(ui): cover settings export/import flows + view-model delegates

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: HabitDetailScreen reminder flows

Covers `habit_detail_screen.dart` 102-107 (edit existing reminder time via row tap), 143-144 (`_toHhmm`), 158-164 (toggle reminder ON → time picker → setReminder), 167-181 (`_pickReminderTime`).

**Files:**
- Modify: `test/ui/habit_detail_screen_test.dart`

**Interfaces:**
- Consumes: the file's existing `app(db, id)` + `seedHabit(db)` helpers and `_FixedCurrentDay`; `habitDetailViewModelProvider(id)`; `showTimePicker` (driven through the Material time-picker dialog).

- [ ] **Step 1: Read `habit_detail_screen.dart`** (95-185) to confirm the reminder row/switch keys (planning saw `reminder-row`, `reminder-switch`) and that toggling the switch ON / tapping the row opens `showTimePicker`. Confirm `habitDetailViewModelProvider(id).notifier.setReminder(String hhmm)`.

- [ ] **Step 2: Toggle-ON flow** (covers 158-164 + `_toHhmm` 143-144)

```dart
  testWidgets('toggling the reminder on opens the time picker and saves it', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await seedHabit(db);
    await tester.pumpWidget(app(db, id));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reminder-switch'))); // turn ON → showTimePicker
    await tester.pumpAndSettle();

    // The Material time picker is up; accept the default (09:00) via OK.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final saved = (await db.habitDao.getHabitsWithDates()).single.habit.reminderTime;
    expect(saved, '09:00'); // _toHhmm(09:00)
  });
```

- [ ] **Step 3: Edit-existing flow** (covers 102-107 + `_pickReminderTime` 167-181)

```dart
  testWidgets('tapping the reminder row edits the existing time', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await seedHabit(db);
    await db.habitDao.setReminderTime(id, '08:00');
    await tester.pumpWidget(app(db, id));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reminder-row'))); // showTimePicker(initial 08:00)
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // keep 08:00 → setReminder (line 180)
    await tester.pumpAndSettle();

    expect(
      (await db.habitDao.getHabitsWithDates()).single.habit.reminderTime,
      '08:00',
    );
  });
```

> The Material time picker's confirm label is `OK` in English; if the dialog opens in input mode and the keypad blocks the tap, call `tester.tap(find.byIcon(Icons.access_time))` first or enter the picker's text field — read the failure and adjust. Confirm the two keys from Step 1; if the row uses a different tap target (e.g. the whole `ListTile`), target that.

- [ ] **Step 4: Run + confirm pass + coverage**

```bash
flutter test test/ui/habit_detail_screen_test.dart
just coverage
```
Expected: PASS; `habit_detail_screen.dart` at 100%.

- [ ] **Step 5: Commit**

```bash
git add test/ui/habit_detail_screen_test.dart
git commit -m "test(ui): cover habit-detail reminder add/edit time-picker flows

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 12: HabitListScreen settings-nav + reorder

Covers `habit_list_screen.dart` 12 (const ctor), 26-29 (settings `Navigator.push`), 47 + 55-59 (the `ReorderableListView` data branch + `onReorder` → `reorder`).

**Files:**
- Modify: `test/ui/habit_list_screen_test.dart`

**Interfaces:**
- Consumes: the file's existing `_app(db)` helper; `habitListViewModelProvider`; `SettingsScreen` (navigation target).

- [ ] **Step 1: Read `habit_list_screen.dart`** to confirm the settings button key (planning saw `open-settings`) and the reorder callback wiring (`onReorder` → `ref.read(habitListViewModelProvider.notifier).reorder(...)`). Confirm a settings-screen marker to assert post-navigation (e.g. `Key('export-data')` is on `SettingsScreen`).

- [ ] **Step 2: Settings navigation test**

```dart
  testWidgets('tapping settings pushes the settings screen', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-settings'))); // lines 26-29
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('export-data')), findsOneWidget); // on SettingsScreen
  });
```

- [ ] **Step 3: Reorder test — invoke the callback directly** (covers 47 + 55-59 without a flaky long-press drag)

```dart
  testWidgets('reordering habits persists the new order', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final a = await db.habitDao.createHabit(name: 'A', color: 1);
    final b = await db.habitDao.createHabit(name: 'B', color: 2);
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    list.onReorder(0, 2); // move A to the end (ReorderableListView newIndex semantics)
    await tester.pumpAndSettle();

    final order = (await db.habitDao.getHabitsWithDates())
        .map((h) => h.habit.id)
        .toList();
    expect(order, [b, a]);
  });
```

Add `import 'package:flutter/material.dart';` if `ReorderableListView` isn't already imported.

> Confirm the widget is a `ReorderableListView` (not `ReorderableListView.builder` → still that type) and the `onReorder` index semantics. If the screen wraps reorder in `DragAndDropLists` or another widget, grab that type instead and call its reorder field — read Step 1's source.

- [ ] **Step 4: Run + confirm pass + coverage**

```bash
flutter test test/ui/habit_list_screen_test.dart
just coverage
```
Expected: PASS; `habit_list_screen.dart` at 100%.

- [ ] **Step 5: Commit**

```bash
git add test/ui/habit_list_screen_test.dart
git commit -m "test(ui): cover habit-list settings nav + reorder callback

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 13: Close to 100%, raise the gate, badge + deferred + architecture

Re-measure, mop up any residual uncovered lines, flip the threshold to 100, refresh the README badge, and tidy planning docs.

**Files:**
- Modify: `Justfile` (the `coverage` recipe threshold)
- Modify: `.github/workflows/ci.yml` (the `coverde check` threshold)
- Modify: `README.md` (coverage badge)
- Modify: `planning/deferred.md`
- Possibly Modify: any test file, to cover a straggler; an `architecture/*.md` if it names the DB connection home

- [ ] **Step 1: Measure and list residuals**

```bash
flutter test --coverage
coverde transform --input coverage/lcov.info --output coverage/lcov.info --transformations preset=exclude-untestable
awk '/^SF:/{sf=$0} /^DA:.*,0$/{print sf" "$0}' coverage/lcov.info
```

- [ ] **Step 2: For each residual line, add a targeted test** following the same patterns as Tasks 4-12 (in-memory DB for data/VM, channel mocks for plugins, widget pump for UI). If a line is genuinely unrunnable under `flutter test`, STOP and confirm with the reviewer before adding any `coverde.yaml` exclusion — the budget is the DB connection + providers (+ `tables.dart` fallback) only.

- [ ] **Step 3: Flip the threshold to 100** in `Justfile`:

```makefile
    coverde check --input coverage/lcov.info 100
```
and in `.github/workflows/ci.yml`:
```yaml
          coverde check --input coverage/lcov.info 100
```

- [ ] **Step 4: Replace the README coverage badge** with a static 100% badge (truthful under the hard gate). Find the current coverage badge line in `README.md` and replace its image with:

```markdown
![coverage](https://img.shields.io/badge/coverage-100%25-brightgreen)
```

> Read `README.md` first to match the existing badge style/placement; if there was no coverage badge, add it alongside the others.

- [ ] **Step 5: Remove the resolved deferred item** — in `planning/deferred.md`, delete the bullet:
> **`NotificationService.syncSchedule` plugin calls untested** … *Revisit if* the scheduling glue changes.

Leave the `share_plus` iPad popover-anchor item (a behavior gap, not coverage).

- [ ] **Step 6: Architecture check** — confirm no `architecture/*.md` describes the database file layout in a way the connection split invalidates:

```bash
grep -rln "driftDatabase\|database.dart\|connection" architecture/
```
If one names `database.dart` as the connection home, update it to mention `connection.dart`.

- [ ] **Step 7: Full verification on a clean, committed tree**

```bash
just lint-ci
just coverage
```
Expected: `coverde check ... 100` PASSES; `just lint-ci` reports no diff.

- [ ] **Step 8: Set the design frontmatter to shipped** — in `planning/changes/2026-06-25.02-coverage-100/design.md` and `plan.md`, set `status: shipped` and fill `pr` / `outcome` once the PR number is known (the PR step).

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "ci: enforce 100% coverage on the filtered set

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:**
- Off-the-shelf coverde pipeline → Task 1. ✓
- Exclusions in `coverde.yaml` → Task 1 (Step 2). ✓
- Gate migrated off `very_good_coverage`; PR-comment + `pull-requests: write` removed → Task 1 (Steps 3-4). ✓
- `connection.dart` split, `database_providers.dart` excluded → Task 1 + Task 2. ✓
- Table getters covered-then-excluded-as-fallback → Task 3. ✓
- DB interaction tested in-memory (Drift convention) → Tasks 3, 6, 10 (and existing repo tests). ✓
- Platform glue covered, not excluded: notifications via an injected mocktail plugin → Task 7; backup via mocked platform interfaces → Task 6; `mocktail` added → Task 1. ✓
- Easy bucket (codec, settings repo guard, current_day, dialogs, recent-days, settings screen/VM, habit-detail, habit-list) → Tasks 4, 5, 8, 9, 10, 11, 12. ✓
- `validateDatabaseSchema()` / migration harness out of scope → not in plan (matches design Out of scope). ✓
- `deferred.md` cleanup (notification item) + iPad anchor left → Task 13 (Step 5). ✓
- Done = `just coverage` 100% + `just lint-ci` clean → Task 13. ✓
- README static badge → Task 13 (Step 4). ✓

**Placeholder scan:** Code is provided for every step. The "verify the exact key/symbol by reading file X" notes are deliberate guards against guessed widget keys (planning read most harnesses verbatim but inferred some `Key` strings), not deferred work — each names the exact file and gives a working default. Task 3 carries an intentional cover-or-exclude conditional (coverage attribution is runtime-confirmed). Task 7's Step 1 confirms the `flutter_local_notifications` method signatures (positional-vs-named `initialize`, the `requestPermissions` param list) and the `flutter_timezone` reply shape against the installed plugin source before the suite is written — the only plugin detail the mocktail approach still depends on.

**Type consistency:** `AppDatabase`, `HabitDao` (`createHabit`/`setReminderTime`/`toggleCompletion`/`reorderHabits`/`importReplace`/`getHabitsWithDates`), `HabitRepository`, `BackupRepository` (`exportAndShare`/`pickAndDecode`), `BackupData`/`BackupHabit`/`BackupFormatException`, `NotificationService` (`init`/`refreshTimeZone`/`hasPermission`/`requestPermission`/`syncSchedule`/`cancelAll`), `ScheduledReminder`, `CurrentDay`/`CurrentDayTicker`/`currentDayProvider`, `settingsViewModelProvider` (`export`/`pickImport`/`applyImport`), `showHabitNameDialog`/`confirmDeleteHabit`/`HabitFormResult`, `RecentDaysList`, and `openConnection()` all match the sources read during planning. Widget `Key` strings flagged "verify" are the only inferred identifiers and each has a read-the-file guard.

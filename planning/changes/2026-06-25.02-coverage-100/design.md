---
status: draft
date: 2026-06-25
slug: coverage-100
summary: Drive coverage to a meaningful 100%; replace tool/coverage.py with coverde, migrate the CI gate off deprecated very_good_coverage, isolate the production DB glue, and cover the notification + backup platform boundaries with mocktail-injected fakes + a channel mock for the one static timezone call (no glue excluded beyond the DB connection).
supersedes: null
superseded_by: null
pr: null
outcome: null
---

# Design: Drive line coverage to a meaningful 100% on off-the-shelf tooling

**Lane:** Full — new file (`connection.dart`), cross-cutting tooling + CI change,
and non-trivial test design (platform-channel mocking).

## Summary

Raise hand-written-code coverage from **84.3%** to a **meaningful 100%** — every
line that can run under `flutter test` is tested. The only exclusions are the
irreducible production database I/O glue (the real file-open), which is covered
by the existing emulator integration test, not by unit coverage. The notification
and backup platform boundaries are **covered with mock method-channel handlers**,
not excluded.

Along the way, replace the bespoke `tool/coverage.py` filter+summary script with
the Dart-native `coverde` CLI, move exclusions into a `coverde.yaml` config (no
inline flag-walls), and migrate the CI gate off the now-deprecated
`very_good_coverage` action to `coverde check`.

## Motivation

`flutter test --coverage` reports **84.3% (815/967 lines, generated excluded)**,
gated at 80. The 152 uncovered lines fall into three buckets:

- **Easily coverable (~84)** — plain logic / widget paths: `current_day.dart`
  ticker (20), `settings_screen` (25) + `settings_view_model` (4),
  `habit_detail_screen` (13), `habit_list_screen` (8), `backup_codec` (5) +
  `backup_data` (2), `habit_dialogs` (4), `recent_days_list` (1),
  `settings_repository` unimplemented guard (2).
- **Production DB glue (~18)** — `database.dart` table column getters + the
  `driftDatabase(name: 'habbits')` file-open (15), and `database_providers.dart`
  (3): providers that can only build a real DB.
- **Platform-channel glue (~50)** — `notification_service.dart` (35:
  `init`, `hasPermission`, `requestPermission`, `syncSchedule`, `cancelAll`,
  `refreshTimeZone`, `scheduledInstant`) and `backup_repository.dart` (15:
  `exportAndShare`, `pickAndDecode`).

Two tooling facts shape the fix. First, **no conventional Dart tool honors
line-level `// coverage:ignore` comments** — `flutter test --coverage`,
`remove_from_coverage`, and `very_good_coverage` all exclude by path/glob only.
So the clean way to drop unrunnable lines is to isolate them into their own files
and glob-exclude those, not to sprinkle bespoke ignore markers. Second,
**`very_good_coverage` (the current gate) was archived/deprecated on
2026-03-31**, so the gate needs to move regardless.

## Decision: platform glue is mocked, not excluded

The notification and backup boundaries call method-channel plugins
(`flutter_local_notifications`, `flutter_timezone`, `share_plus`, `file_picker`,
`path_provider`). Rather than treat them as irreducible glue and exclude the
files (the path the sibling `nooka` project took only for its DB connection),
**this change covers them by injecting test doubles through the boundaries'
existing seams.** `NotificationService` already takes an optional
`FlutterLocalNotificationsPlugin`, and the backup plugins expose settable
platform interfaces (`PathProviderPlatform.instance`, `SharePlatform.instance`,
`FilePicker.platform`) — so the doubles are `mocktail` mocks, not raw
method-channel handlers. The one exception is the static
`FlutterTimezone.getLocalTimezone()` call, which has no injection seam and is
covered with `flutter_test`'s built-in `setMockMethodCallHandler`.

This adds one dev-only dependency, **`mocktail`** (no codegen; the de-facto
Flutter mocking standard). It is preferred over the no-dependency raw-channel
approach because `FlutterLocalNotificationsPlugin` cannot be subclassed (private
generative constructor), so the no-dep path would force brittle guessing of the
plugin's channel method names and the iOS `checkPermissions` reply-map shape;
mocktail stubs typed methods directly.

Consequence: the only file-level coverage exclusions beyond generated code are
`database/connection.dart` and `database/database_providers.dart`. This reverses
the prior `deferred.md` stance that the `syncSchedule` plugin calls were not
worth a mock-method-channel test — that item is removed (see §7).

## Non-goals

- Testing the production database file-open path in unit tests — Drift keeps it
  as injectable glue; it is exercised by the existing KVM emulator integration
  test (`integration_test/`).
- Migration tests (`drift_dev schema generate` / `SchemaVerifier`) — the schema
  is at version 1 with no migrations to test yet.
- Any **behavior** change. This is tests + CI tooling + a test-only code split.
  In particular, the `share_plus` iPad `sharePositionOrigin` gap stays deferred
  (a behavior fix, not coverage).

## Design

### 1. Off-the-shelf pipeline: `coverde` replaces `tool/coverage.py`

Delete `tool/coverage.py`. Coverage filtering and the gate come from `coverde`
(`dart pub global activate coverde`) — Dart-native, no system dependency, no
third-party service.

`just coverage` and CI run:

```sh
flutter test --coverage
coverde transform --input coverage/lcov.info --output coverage/lcov.info --transformations preset=exclude-untestable
coverde check --input coverage/lcov.info <threshold>
```

The threshold stays at the current **80** floor during the backfill and flips to
**100** in the final task. Pin the `coverde` version in CI so the
`transform`/`check` flag surface does not drift.

The per-area Markdown job-summary table that `coverage.py` emitted is dropped,
and the `lcov-reporter-action` per-file PR comment is removed: under a hard 100%
gate it carries no signal — every file is green, and a drop fails `coverde check`
first and logs the uncovered lines. A static `coverage 100%` README badge
(truthful because the gate enforces it) replaces the at-a-glance number.

### 2. Exclusions live in `coverde.yaml`, not command args

A repo-root `coverde.yaml` defines the preset:

```yaml
# coverde.yaml
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

This is the single home for exclusions, mirroring the prior `coverage.py`
philosophy but with a standard tool and config format. Presets compose, so adding
a glue file later is a one-line edit.

### 3. Isolate the unrunnable DB glue into its own files

So the exclusion globs hit precisely the I/O glue and nothing testable:

- **`connection.dart`** — holds `driftDatabase(name: 'habbits')` (the real
  file-open). `AppDatabase`'s production constructor branch delegates to it.
  *Excluded* (covered by the emulator integration test). The `drift_flutter`
  import moves here; `database.dart` no longer imports it.
- **`database_providers.dart`** — providers that can only build a real DB; pure
  wiring. *Excluded as a whole file.*
- `database.dart` keeps `AppDatabase`; its in-memory constructor branch stays
  measured and covered by DAO tests.

**Table column getters** (`Habits` / `Completions`, `database.dart:8-28`) are
*not* excluded by default. They execute when the schema is built, so an in-memory
schema-creation test (open `AppDatabase(NativeDatabase.memory())`, force a
`select` so `migration` runs) should cover them. Implementation verifies this
experimentally; **only if** coverage still credits them to generated code do the
table classes move to a `tables.dart` that gets a glob-exclude entry. Preference
order: cover, then exclude.

### 4. Database interaction is tested the conventional Drift way

DAO/repository query logic is tested against an in-memory database:

```dart
AppDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);
```

Any uncovered `habit_repository` / `settings_repository` lines are filled with
ordinary in-memory tests, not mocks or exclusions.

### 5. Platform channels are covered with mock handlers

No file exclusions here — the boundaries are exercised through their test seams.

- **`notification_service.dart`** — a `mocktail` mock of
  `FlutterLocalNotificationsPlugin` is injected via the constructor seam. Tests
  stub the typed methods (`initialize`, `cancelAll`, `zonedSchedule`, and the
  `resolvePlatformSpecificImplementation<…>()` dispatch returning mocked
  Android/iOS implementations) to reach both the iOS and Android branches of
  `hasPermission` / `requestPermission`. They `verify` that `syncSchedule`
  cancels-all then schedules one notification per reminder at the right
  `scheduledInstant`, and cover `cancelAll` and the pure `scheduledInstant` tz
  math directly. `init` / `refreshTimeZone` additionally need the static
  `FlutterTimezone.getLocalTimezone()` mocked via `setMockMethodCallHandler` on
  the `flutter_timezone` channel.
- **`backup_repository.dart`** — `exportAndShare` / `pickAndDecode` are covered
  by swapping the plugins' platform interfaces for `mocktail` mocks (mixing in
  `MockPlatformInterfaceMixin`): `PathProviderPlatform.instance` returns a real
  temp dir (so the actual `File` write/read runs), `SharePlatform.instance`
  records the share, and `FilePicker.platform` returns a chosen path (and `null`
  for the cancelled-pick branch).

If a specific line proves genuinely unrunnable under `flutter test`, the
implementer surfaces it for a ruling rather than silently excluding it — the
exclusion budget is the DB connection + providers (+ the `tables.dart` fallback)
only.

### 6. Easy bucket: logic + widget tests

`current_day.dart`'s `CurrentDayTicker` is covered by a widget test that pumps
past the computed next-midnight `Timer`, dispatches an app-resume lifecycle
event, and disposes the widget (covering `_arm` / `_refresh` / `dispose`).
`settings_screen` / `settings_view_model`, `habit_detail_screen`,
`habit_list_screen`, `habit_dialogs`, and `recent_days_list` get widget tests
that drive the uncovered branches; `backup_codec` / `backup_data` get edge-case
decode tests; `settings_repository` gets the unimplemented-provider guard test.

### 7. CI gate migration + deferred cleanup

Replace the deprecated `very_good_coverage` step and the `lcov-reporter-action`
comment step in `.github/workflows/ci.yml` with `dart pub global activate
coverde` + the `transform`/`check` invocation from §1 (pinned version). Remove
the now-unused `pull-requests: write` permission.

Remove the resolved item from `planning/deferred.md`:
*"`NotificationService.syncSchedule` plugin calls untested"* — this change tests
exactly that path.

## Operations

None out-of-repo. CI installs `coverde` via `dart pub global activate`.

## Out of scope

- **`validateDatabaseSchema()` runtime self-check** — *revisit when* the first
  real migration lands (`schemaVersion` reaches 2).
- **Migration test harness** (`SchemaVerifier`) — same revisit trigger.
- **`share_plus` iPad `sharePositionOrigin`** — a behavior fix; stays in
  `deferred.md`.

## Testing

- `just coverage` (now `coverde check … 100`) passes locally and in CI at the
  100% threshold over the filtered lcov.
- New/expanded tests: in-memory schema + DAO/repository tests; `current_day`
  ticker widget test; widget tests for settings / habit-detail / habit-list /
  dialogs; `backup_codec` edge cases; mocktail-injected tests for
  `notification_service` (both platform branches) and `backup_repository`.
- `just lint-ci` clean on an already-committed tree.

## Risk

- **Table getters may stay credited to generated code** (medium × low) —
  fallback is the `tables.dart` split + glob-exclude; design already accounts for
  it.
- **`flutter_local_notifications` mock surface** (low × medium) — the
  `resolvePlatformSpecificImplementation` dispatch is the fiddliest part; with
  `mocktail` it is stubbed to return mocked Android/iOS implementations, removing
  the channel-reply-shape guessing. Surface (don't exclude) any line that still
  proves unrunnable.
- **`coverde` flag/preset surface changes** (low × medium) — mitigate by pinning
  the version in CI.
- **Hidden unrunnable lines surface once the gate is 100%** (medium × low) — e.g.
  `main.dart` `runApp` wiring. Mitigation: presets compose, so excluding an
  additional glue file is a one-line `coverde.yaml` edit; the exclusion list is
  treated as extensible, not fixed (but any addition is surfaced for a ruling).

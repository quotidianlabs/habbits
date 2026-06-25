# Local Reminders Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Per-habit daily reminders — set a time on a habit and get nudged on days you haven't done it — scheduled fully on-device via a rolling buffer of one-shot local notifications.

**Architecture:** A pure `computeReminderSchedule` holds all the decision logic (which habits, which upcoming uncompleted days, the iOS-64 budget split, skip-today). The DAO gains `setReminderTime`. A `NotificationService` wraps `flutter_local_notifications` + `timezone` (the plugin boundary). A root-mounted `ReminderCoordinator` watches the reactive habit stream + app lifecycle, runs the pure scheduler, requests permission when needed, and tells the service to resync. The detail screen gets a Reminder row that only writes `reminder_time` to the DB — the coordinator reacts.

**Tech Stack:** Flutter, Drift, Riverpod; `flutter_local_notifications`, `timezone`, `flutter_timezone`.

**Source spec:** `docs/superpowers/specs/2026-06-14-reminders-design.md`.

**Pre-flight:** Flutter on PATH (`/opt/homebrew/bin`; `export PATH="/opt/homebrew/bin:$PATH"`). Android SDK env for the smoke build: `export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools ANDROID_SDK_ROOT=$ANDROID_HOME JAVA_HOME=/opt/homebrew/opt/openjdk@17; export PATH="$JAVA_HOME/bin:$PATH"`. Branch `feat/reminders` (confirm `git branch --show-current`; if detached, STOP).

**Existing interfaces:** `lib/state/habit_providers.dart` → `habitSummariesProvider` (Stream of `HabitSummary`), `habitDaoProvider`; `HabitSummary{habit, streak, doneToday, completionPercent, dates}`, `habit` has `.id/.name/.color/.reminderTime(String?)/.sortOrder/.createdAt`. `lib/data/habit_dao.dart` → `HabitDao`. `lib/data/database.dart` → `habits.reminderTime` is a nullable TEXT column. `lib/ui/habit_detail/habit_detail_screen.dart` is a `ConsumerWidget`.

**Note on plugin APIs:** `flutter_local_notifications`, `timezone`, and `flutter_timezone` change APIs across versions and are being used on the 4-day-old Flutter 3.44. Where this plan shows plugin calls, **verify against the installed version** (use the Context7 MCP `flutter_local_notifications` docs, or the package README) and adapt minimally; `flutter analyze` is the gate that they compile. The native Android/iOS setup in Task 1 is version-sensitive — follow the installed version's README.

---

### Task 1: Add packages, native setup, and an early smoke build

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/build.gradle.kts`
- Modify: `android/app/src/main/AndroidManifest.xml`

This task de-risks the Flutter-3.44 plugin compatibility before any feature code (per the spec). It ends with a smoke **debug** build that proves the native side compiles.

- [ ] **Step 1: Add the packages**

```bash
flutter pub add flutter_local_notifications timezone flutter_timezone
```
Expected: all three under `dependencies:`; `flutter pub get` resolves. If the solver conflicts (as `win32` did for share_plus/file_picker), let it resolve and report the chosen versions; if it cannot, report BLOCKED with the solver output.

- [ ] **Step 2: Check the installed flutter_local_notifications setup requirements**

Look up the installed version's required Android/iOS setup (use Context7 MCP docs for `flutter_local_notifications`, or read `~/.pub-cache/hosted/pub.dev/flutter_local_notifications-*/README.md`). The setup below is the common shape for v17–v19; reconcile with the installed version.

- [ ] **Step 3: Enable Android core-library desugaring** in `android/app/build.gradle.kts`

Inside the `android { ... }` block add (or merge) a `compileOptions` enabling desugaring, and add the desugar dependency. The `android` block should include:

```kotlin
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
```

and at the file's top level (after the `android { }` block) a dependencies block:

```kotlin
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

Use the desugar_jdk_libs version the installed flutter_local_notifications README specifies (≥ the version it requires). If the file already declares `compileOptions`, merge the desugaring lines into it rather than duplicating the block.

- [ ] **Step 4: Add Android permissions** to `android/app/src/main/AndroidManifest.xml`

Inside `<manifest>` (above `<application>`) add:

```xml
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

(We use inexact scheduling, so `SCHEDULE_EXACT_ALARM` is NOT needed. `RECEIVE_BOOT_COMPLETED` lets scheduled notifications survive a reboot; the app also reschedules on open.) If the installed plugin version's README requires specific `<receiver>` entries in `<application>`, add exactly those; recent versions ship their receivers in the plugin manifest and need none here.

- [ ] **Step 5: Smoke build (the de-risk)**

```bash
flutter analyze
flutter build apk --debug
```
Expected: analyze clean; `✓ Built ... app-debug.apk`. This compiles all three plugins' native code. **If the build fails** (e.g. an AAR-metadata / Kotlin / desugaring error like file_picker hit), pin compatible plugin/transitive versions or add a `dependency_overrides` exactly as we did for `flutter_plugin_android_lifecycle`, documenting why. Do not proceed to Task 2 until the debug build succeeds — report BLOCKED with the error if it cannot be made to build.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/build.gradle.kts android/app/src/main/AndroidManifest.xml
git commit -m "chore: add notification plugins + android setup; verify debug build"
```

---

### Task 2: `computeReminderSchedule` (pure)

**Files:**
- Create: `lib/domain/reminder_schedule.dart`
- Test: `test/domain/reminder_schedule_test.dart`

The brain: given the enabled habits and `now`, produce the list of notifications to schedule.

- [ ] **Step 1: Write the failing test** — `test/domain/reminder_schedule_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/reminder_schedule.dart';

void main() {
  // now = Saturday 2026-06-14, 10:00 local.
  final now = DateTime(2026, 6, 14, 10, 0);

  ReminderHabit habit(int id, String time, {bool done = false}) =>
      ReminderHabit(id: id, name: 'H$id', time: time, doneToday: done);

  test('no enabled habits -> empty schedule', () {
    expect(computeReminderSchedule(const [], now), isEmpty);
  });

  test('one habit, not done, time later today -> today + 13 future days', () {
    final s = computeReminderSchedule([habit(1, '20:00')], now);
    expect(s.length, 14); // maxBuffer
    expect(s.first.habitId, 1);
    expect(s.first.when, DateTime(2026, 6, 14, 20, 0)); // today 20:00
    expect(s.last.when, DateTime(2026, 6, 27, 20, 0)); // +13 days
  });

  test('today is skipped when the habit is already done today', () {
    final s = computeReminderSchedule([habit(1, '20:00', done: true)], now);
    expect(s.length, 13);
    expect(s.first.when, DateTime(2026, 6, 15, 20, 0)); // starts tomorrow
  });

  test("today is skipped when its time has already passed", () {
    // 08:00 is before now (10:00).
    final s = computeReminderSchedule([habit(1, '08:00')], now);
    expect(s.length, 13);
    expect(s.first.when, DateTime(2026, 6, 15, 8, 0));
  });

  test('iOS budget splits days across habits and total stays <= 64', () {
    final habits = [for (var i = 1; i <= 8; i++) habit(i, '20:00')];
    final s = computeReminderSchedule(habits, now);
    expect(s.length, 64); // 8 habits * (64/8 = 8) days
    final perHabit = <int, int>{};
    for (final r in s) {
      perHabit[r.habitId] = (perHabit[r.habitId] ?? 0) + 1;
    }
    expect(perHabit.values.every((c) => c == 8), isTrue);
  });

  test('carries the habit name and times across days', () {
    final s = computeReminderSchedule([habit(7, '07:30')], now);
    expect(s.every((r) => r.habitName == 'H7'), isTrue);
    expect(s.every((r) => r.when.hour == 7 && r.when.minute == 30), isTrue);
  });
}
```

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/domain/reminder_schedule_test.dart
```
Expected: FAIL — undefined symbols.

- [ ] **Step 3: Implement `lib/domain/reminder_schedule.dart`**

```dart
/// A habit that has a reminder enabled.
class ReminderHabit {
  const ReminderHabit({
    required this.id,
    required this.name,
    required this.time,
    required this.doneToday,
  });
  final int id;
  final String name;
  final String time; // 'HH:mm'
  final bool doneToday;
}

/// One notification to schedule.
class ScheduledReminder {
  const ScheduledReminder({
    required this.habitId,
    required this.habitName,
    required this.when,
  });
  final int habitId;
  final String habitName;
  final DateTime when; // local wall-clock instant
}

/// Builds the reminder schedule: for each enabled habit, one notification per
/// upcoming day it isn't done, within a rolling buffer sized to respect iOS's
/// pending-notification cap. Today is included only if the habit isn't done and
/// its time is still in the future relative to [now].
List<ScheduledReminder> computeReminderSchedule(
  List<ReminderHabit> enabled,
  DateTime now, {
  int maxBuffer = 14,
  int iosBudget = 64,
}) {
  if (enabled.isEmpty) return const [];
  final days = (iosBudget ~/ enabled.length).clamp(1, maxBuffer);
  final result = <ScheduledReminder>[];
  for (final h in enabled) {
    final parts = h.time.split(':');
    final hh = int.parse(parts[0]);
    final mm = int.parse(parts[1]);
    for (var d = 0; d < days; d++) {
      final when = DateTime(now.year, now.month, now.day + d, hh, mm);
      if (d == 0) {
        if (h.doneToday) continue; // already done today
        if (!when.isAfter(now)) continue; // time already passed today
      }
      result.add(ScheduledReminder(
        habitId: h.id,
        habitName: h.name,
        when: when,
      ));
    }
  }
  return result;
}
```

- [ ] **Step 4: Run to verify pass**

```bash
flutter test test/domain/reminder_schedule_test.dart
```
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/reminder_schedule.dart test/domain/reminder_schedule_test.dart
git commit -m "feat(domain): add reminder schedule computation"
```

---

### Task 3: DAO `setReminderTime`

**Files:**
- Modify: `lib/data/habit_dao.dart`
- Test: `test/data/habit_dao_test.dart`

- [ ] **Step 1: Add the failing test** — append inside the existing `main()` in `test/data/habit_dao_test.dart`:

```dart
  test('setReminderTime sets and clears a habit reminder', () async {
    final id = await dao.createHabit(name: 'Read', color: 1);

    await dao.setReminderTime(id, '08:30');
    var rows = await dao.getHabitsWithDates();
    expect(rows.single.habit.reminderTime, '08:30');

    await dao.setReminderTime(id, null);
    rows = await dao.getHabitsWithDates();
    expect(rows.single.habit.reminderTime, isNull);
  });
```

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/data/habit_dao_test.dart
```
Expected: FAIL — `setReminderTime` undefined.

- [ ] **Step 3: Add the method** to `lib/data/habit_dao.dart`, after `renameHabit`:

```dart
  Future<void> setReminderTime(int id, String? hhmm) {
    return (update(habits)..where((h) => h.id.equals(id)))
        .write(HabitsCompanion(reminderTime: Value(hhmm)));
  }
```

- [ ] **Step 4: Run to verify pass**

```bash
flutter test test/data/habit_dao_test.dart
```
Expected: PASS (existing + 1 new).

- [ ] **Step 5: Commit**

```bash
git add lib/data/habit_dao.dart test/data/habit_dao_test.dart
git commit -m "feat(data): add setReminderTime"
```

---

### Task 4: `NotificationService` (plugin wrapper) + provider

**Files:**
- Create: `lib/services/notification_service.dart`
- Modify: `lib/state/habit_providers.dart` (add `notificationServiceProvider`)

The thin plugin boundary. Not unit-tested (verified on device); `flutter analyze` gates that it compiles.

- [ ] **Step 1: Implement `lib/services/notification_service.dart`**

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminder_schedule.dart';

/// Wraps flutter_local_notifications + timezone for on-device habit reminders.
/// This is the plugin boundary; all decision logic lives in
/// computeReminderSchedule.
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  static const _channelId = 'habit_reminders';
  static const _channelName = 'Habit reminders';

  Future<void> init() async {
    tzdata.initializeTimeZones();
    final localName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localName));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
      const AndroidNotificationChannel(_channelId, _channelName),
    );
  }

  /// Asks the OS for notification permission. Returns true if granted.
  Future<bool> requestPermission() async {
    final ios = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    final android = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    return ios ?? android ?? false;
  }

  /// Cancels everything and reschedules exactly [reminders].
  Future<void> syncSchedule(List<ScheduledReminder> reminders) async {
    await _plugin.cancelAll();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.defaultImportance,
      ),
      iOS: DarwinNotificationDetails(),
    );
    for (var i = 0; i < reminders.length; i++) {
      final r = reminders[i];
      await _plugin.zonedSchedule(
        i,
        r.habitName,
        'Time to check in',
        tz.TZDateTime.from(r.when, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}
```

VERIFY against the installed plugin version: `zonedSchedule`'s named params (older versions also require `uiLocalNotificationDateInterpretation:` and use `androidAllowWhileIdle:` instead of `androidScheduleMode:`); `requestNotificationsPermission` vs `requestPermission`; `FlutterTimezone.getLocalTimezone()`'s return type (some versions return an object — use its `.identifier`). Adapt minimally so `flutter analyze` is clean; report what you changed.

- [ ] **Step 2: Add `notificationServiceProvider`** to `lib/state/habit_providers.dart`

Add the import at the top:
```dart
import '../services/notification_service.dart';
```
and the provider (a plain provider, overridden in `main` with the initialized instance):
```dart
@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) =>
    throw UnimplementedError('notificationServiceProvider must be overridden in main');
```

- [ ] **Step 3: Regenerate + analyze**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
```
Expected: codegen adds `notificationServiceProvider`; analyze clean (confirms all plugin calls compile). Run `flutter test` to confirm nothing regressed.

- [ ] **Step 4: Commit**

```bash
git add lib/services/notification_service.dart lib/state/habit_providers.dart lib/state/habit_providers.g.dart
git commit -m "feat(services): add NotificationService plugin wrapper + provider"
```

---

### Task 5: `ReminderCoordinator` + wire into main

**Files:**
- Create: `lib/state/reminder_coordinator.dart`
- Modify: `lib/main.dart`

A non-visual widget mounted above the app that watches the habit stream + app lifecycle, computes the schedule, requests permission once when needed, and resyncs the service.

- [ ] **Step 1: Implement `lib/state/reminder_coordinator.dart`**

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/reminder_schedule.dart';
import 'habit_providers.dart';

/// Watches habits + app lifecycle and keeps the OS notification schedule in
/// sync. Renders [child] unchanged.
class ReminderCoordinator extends ConsumerStatefulWidget {
  const ReminderCoordinator({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ReminderCoordinator> createState() => _ReminderCoordinatorState();
}

class _ReminderCoordinatorState extends ConsumerState<ReminderCoordinator> {
  AppLifecycleListener? _lifecycle;
  bool _permissionAsked = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _sync);
    // Resync whenever habits/completions change.
    ref.listenManual(habitSummariesProvider, (_, __) => _sync());
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    final summaries = ref.read(habitSummariesProvider).valueOrNull;
    if (summaries == null) return;

    final enabled = [
      for (final s in summaries)
        if (s.habit.reminderTime != null)
          ReminderHabit(
            id: s.habit.id,
            name: s.habit.name,
            time: s.habit.reminderTime!,
            doneToday: s.doneToday,
          ),
    ];

    final service = ref.read(notificationServiceProvider);
    if (enabled.isNotEmpty && !_permissionAsked) {
      _permissionAsked = true;
      await service.requestPermission();
    }
    await service.syncSchedule(computeReminderSchedule(enabled, DateTime.now()));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
```

(`valueOrNull` is the Riverpod 3.x getter for an `AsyncValue`'s data — verify it matches what the codebase already uses in `habit_providers.dart`; if that file uses `.value`, use `.value` here too.)

- [ ] **Step 2: Wire into `lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/notification_service.dart';
import 'state/habit_providers.dart';
import 'state/reminder_coordinator.dart';
import 'ui/habit_list/habit_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notifications = NotificationService();
  await notifications.init();
  runApp(
    ProviderScope(
      overrides: [notificationServiceProvider.overrideWithValue(notifications)],
      child: const HabbitsApp(),
    ),
  );
}

class HabbitsApp extends StatelessWidget {
  const HabbitsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habbits',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const ReminderCoordinator(child: HabitListScreen()),
    );
  }
}
```

- [ ] **Step 3: Analyze + full suite**

```bash
flutter analyze
flutter test
```
Expected: analyze clean; all tests pass. The widget tests that pump `HabitListScreen` directly are unaffected (they don't mount `ReminderCoordinator`). If any widget test pumps `HabbitsApp` (full app) it would now require a `notificationServiceProvider` override — none currently do; if one fails for that reason, override it with a `NotificationService` in that test or pump `HabitListScreen` directly.

- [ ] **Step 4: Commit**

```bash
git add lib/state/reminder_coordinator.dart lib/main.dart
git commit -m "feat(state): add ReminderCoordinator and wire notifications in main"
```

---

### Task 6: Reminder row on the detail screen

**Files:**
- Modify: `lib/ui/habit_detail/habit_detail_screen.dart`
- Test: `test/ui/habit_detail_screen_test.dart`

A Reminder row (switch + time) that only writes `reminder_time` to the DB; the coordinator reacts to the stream change. No notification-service dependency here → easy to test.

- [ ] **Step 1: Add failing tests** to `test/ui/habit_detail_screen_test.dart` (append inside `main()`; the file already has `seedHabit`, `app`, and imports for drift/database/dates):

```dart
  testWidgets('reminder row shows Off and switch off for a habit with no reminder',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await seedHabit(db);

    await tester.pumpWidget(app(db, id));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reminder-row')), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
    final sw = tester.widget<Switch>(find.byKey(const Key('reminder-switch')));
    expect(sw.value, isFalse);
  });

  testWidgets('reminder row shows the time and switch on when set', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await seedHabit(db);
    await db.habitDao.setReminderTime(id, '08:30');

    await tester.pumpWidget(app(db, id));
    await tester.pumpAndSettle();

    final sw = tester.widget<Switch>(find.byKey(const Key('reminder-switch')));
    expect(sw.value, isTrue);
    expect(find.text('8:30 AM'), findsOneWidget);
  });

  testWidgets('toggling the switch off clears the reminder', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await seedHabit(db);
    await db.habitDao.setReminderTime(id, '08:30');

    await tester.pumpWidget(app(db, id));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reminder-switch')));
    await tester.pumpAndSettle();

    final rows = await db.habitDao.getHabitsWithDates();
    expect(rows.single.habit.reminderTime, isNull);
  });
```

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/ui/habit_detail_screen_test.dart
```
Expected: FAIL — no `reminder-row`/`reminder-switch` yet.

- [ ] **Step 3: Add the Reminder row** to `lib/ui/habit_detail/habit_detail_screen.dart`

Add this import at the top (with the others):
```dart
import 'package:flutter/material.dart' show TimeOfDay;
```
(That symbol comes from the existing `package:flutter/material.dart` import, so no new import is actually required — skip if already covered.)

Insert a Reminder `ListTile` into the detail `ListView`, right after the `30-day` Text and its `SizedBox`, before the heatmap's `SingleChildScrollView`. Replace the block:

```dart
          Text('30-day: ${percent == null ? '—' : '$percent%'}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          SingleChildScrollView(
```

with:

```dart
          Text('30-day: ${percent == null ? '—' : '$percent%'}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            key: const Key('reminder-row'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Reminder'),
            subtitle: Text(_reminderLabel(context, summary.habit.reminderTime)),
            trailing: Switch(
              key: const Key('reminder-switch'),
              value: summary.habit.reminderTime != null,
              onChanged: (on) =>
                  _onReminderToggle(context, ref, habitId, on, summary.habit.reminderTime),
            ),
            onTap: summary.habit.reminderTime == null
                ? null
                : () => _pickReminderTime(
                    context, ref, habitId, summary.habit.reminderTime!),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
```

Then add these top-level helper functions at the end of the file (after the class):

```dart
String _reminderLabel(BuildContext context, String? hhmm) {
  if (hhmm == null) return 'Off';
  return _toTimeOfDay(hhmm).format(context);
}

TimeOfDay _toTimeOfDay(String hhmm) {
  final parts = hhmm.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

String _toHhmm(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

Future<void> _onReminderToggle(
  BuildContext context,
  WidgetRef ref,
  int habitId,
  bool on,
  String? current,
) async {
  final dao = ref.read(habitDaoProvider);
  if (!on) {
    await dao.setReminderTime(habitId, null);
    return;
  }
  final picked = await showTimePicker(
    context: context,
    initialTime: const TimeOfDay(hour: 9, minute: 0),
  );
  if (picked != null) {
    await dao.setReminderTime(habitId, _toHhmm(picked));
  }
}

Future<void> _pickReminderTime(
  BuildContext context,
  WidgetRef ref,
  int habitId,
  String current,
) async {
  final picked = await showTimePicker(
    context: context,
    initialTime: _toTimeOfDay(current),
  );
  if (picked != null && context.mounted) {
    await ref.read(habitDaoProvider).setReminderTime(habitId, _toHhmm(picked));
  }
}
```

- [ ] **Step 4: Run the detail tests + full suite + analyze**

```bash
flutter test test/ui/habit_detail_screen_test.dart
flutter analyze
flutter test
```
Expected: the 3 new reminder-row tests pass (plus the existing detail tests); analyze clean; full suite green. NOTE on the "8:30 AM" assertion: `TimeOfDay.format(context)` depends on locale/24h setting. The test runs under the default `MaterialApp` locale (en_US, 12-hour) so it renders `8:30 AM`. If your environment formats differently, adjust the expected string to what `_toTimeOfDay('08:30').format(context)` produces (do not change the production code). The toggle-on→time-picker→save path is verified on device, not asserted here (the system `showTimePicker` dialog is awkward to drive in a widget test).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/habit_detail/habit_detail_screen.dart test/ui/habit_detail_screen_test.dart
git commit -m "feat(ui): add per-habit reminder row (switch + time picker)"
```

---

### Task 7: Final verification + smoke build

No code changes.

- [ ] **Step 1: Analyze + full suite**

```bash
flutter analyze
flutter test
```
Expected: `No issues found!`; all tests pass (domain reminder_schedule, dao setReminderTime, ui reminder row, plus all prior suites).

- [ ] **Step 2: Confirm the release build still works**

```bash
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools; export ANDROID_SDK_ROOT=$ANDROID_HOME; export JAVA_HOME=/opt/homebrew/opt/openjdk@17; export PATH="/opt/homebrew/bin:$JAVA_HOME/bin:$PATH"
flutter build apk --release 2>&1 | tail -3
```
Expected: `✓ Built ... app-release.apk`. (This is the real device artifact; the notification plugins must build in release too.)

- [ ] **Step 3: Confirm clean tree + branch**

```bash
git status
git branch --show-current   # expect feat/reminders, NOT detached
git log --oneline -7 | cat
```
Expected: clean tree; on `feat/reminders`; the 6 implementation commits present.

The merged `integration_test/critical_flow_test.dart` is unaffected (home unchanged; detail gains a reminder row but the integration test only touches the home Checkbox + Streak text).

---

## Self-review notes

- **Spec coverage:**
  - §1 scheduling model (buffer of upcoming uncompleted days, skip-today when done/time-passed, N=min(14,64/count), reschedule on stream + resume, inexact Android, timezone): Task 2 (`computeReminderSchedule`), Task 4 (`syncSchedule` inexact + tz), Task 5 (coordinator: stream listen + `AppLifecycleListener.onResume`).
  - §2 per-habit UI (switch + time picker, save/clear `reminder_time`, permission on first enable): Task 6 (row → `setReminderTime`), Task 5 (coordinator requests permission once when a reminder exists).
  - §3 content (title=name, body nudge, tap→home, channel): Task 4 (`syncSchedule` details + channel).
  - §4 architecture (pure schedule, DAO setter, service boundary, coordinator, row, main wiring): Tasks 2–6.
  - §5 testing (pure schedule table tests; DAO setter; UI row render/clear; plugin boundary device-only): Tasks 2, 3, 6.
  - §6 risk (early smoke build) + out-of-scope (no notification actions/snooze/etc.): Task 1 smoke build; nothing out-of-scope added.
- **Placeholder scan:** none. Plugin-API and native-setup variance is explicitly flagged with the "verify against installed version" instruction and the analyze/smoke-build gates, not left vague.
- **Type/name consistency:** `ReminderHabit{id,name,time,doneToday}` and `ScheduledReminder{habitId,habitName,when}` (Task 2) are consumed identically by `NotificationService.syncSchedule` (Task 4) and the coordinator (Task 5); `computeReminderSchedule(List<ReminderHabit>, DateTime, {maxBuffer, iosBudget})` signature matches across Tasks 2/5; `setReminderTime(int, String?)` (Task 3) used in Tasks 5/6; `notificationServiceProvider` (Task 4) overridden in `main` (Task 5) and read in the coordinator; widget keys `reminder-row`/`reminder-switch` consistent between Task 6 code and its test.
- **Known judgment calls:** permission is requested by the coordinator (not the screen) so the detail screen stays service-free and unit-testable; `syncSchedule` uses `cancelAll`+reschedule with index ids (simplest, since we always rebuild the whole set); the toggle-on time-picker path is device-verified rather than widget-tested because the system `showTimePicker` dialog is awkward to drive.

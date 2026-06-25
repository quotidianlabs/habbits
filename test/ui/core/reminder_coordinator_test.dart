import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/repositories/settings_repository.dart';
import 'package:habbits/data/services/database/database.dart';
import 'package:habbits/data/services/database/database_providers.dart';
import 'package:habbits/data/services/notification_service.dart';
import 'package:habbits/domain/reminder_schedule.dart';
import 'package:habbits/l10n/app_localizations.dart';
import 'package:habbits/ui/core/notification_permission.dart';
import 'package:habbits/ui/core/reminder_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotificationService extends NotificationService {
  int syncCalls = 0;
  List<ScheduledReminder> last = const [];
  bool throwOnSync = false;
  bool permission = true;
  int refreshCalls = 0;

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<void> refreshTimeZone() async => refreshCalls++;

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> syncSchedule(
    List<ScheduledReminder> reminders, {
    required String body,
    required String channelName,
  }) async {
    syncCalls++;
    last = reminders;
    if (throwOnSync) throw Exception('boom');
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  AppDatabase db,
  _FakeNotificationService fake,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationServiceProvider.overrideWithValue(fake),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ReminderCoordinator(child: SizedBox()),
      ),
    ),
  );
  return container;
}

Future<int> _seedReminderHabit(AppDatabase db) async {
  final id = await db.habitDao.createHabit(name: 'Read', color: 1);
  await db.habitDao.setReminderTime(id, '23:59');
  return id;
}

void main() {
  testWidgets('syncs reminders for a reminder-enabled habit', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await _seedReminderHabit(db);
    final fake = _FakeNotificationService();

    await _pump(tester, db, fake);
    await tester.pumpAndSettle();

    expect(fake.syncCalls, greaterThan(0));
    expect(fake.last.any((r) => r.habitId == id), isTrue);
  });

  testWidgets('a failing notification service does not crash', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedReminderHabit(db);
    final fake = _FakeNotificationService()..throwOnSync = true;

    await _pump(tester, db, fake);
    await tester.pumpAndSettle();

    expect(fake.syncCalls, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('records denied notification permission', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedReminderHabit(db);
    final fake = _FakeNotificationService()..permission = false;

    final container = await _pump(tester, db, fake);
    await tester.pumpAndSettle();

    expect(container.read(notificationPermissionProvider), false);
  });

  testWidgets('records granted notification permission', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedReminderHabit(db);
    final fake = _FakeNotificationService(); // permission = true

    final container = await _pump(tester, db, fake);
    await tester.pumpAndSettle();

    expect(container.read(notificationPermissionProvider), true);
  });

  testWidgets('re-enabling permission flips the provider on resume', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedReminderHabit(db);
    final fake = _FakeNotificationService()..permission = false;

    final container = await _pump(tester, db, fake);
    await tester.pumpAndSettle();
    expect(container.read(notificationPermissionProvider), false);

    // User enables notifications in system settings, then returns to the app.
    fake.permission = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(container.read(notificationPermissionProvider), true);
  });

  testWidgets('a removed reminder drops out of the next sync', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await _seedReminderHabit(db);
    final fake = _FakeNotificationService();

    await _pump(tester, db, fake);
    await tester.pumpAndSettle();
    expect(fake.last.any((r) => r.habitId == id), isTrue);

    await db.habitDao.setReminderTime(id, null);
    await tester.pumpAndSettle();
    expect(fake.last.any((r) => r.habitId == id), isFalse);
  });

  testWidgets('refreshes the timezone on resume', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedReminderHabit(db);
    final fake = _FakeNotificationService();

    await _pump(tester, db, fake);
    await tester.pumpAndSettle();
    final before = fake.refreshCalls;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(fake.refreshCalls, greaterThan(before));
  });
}

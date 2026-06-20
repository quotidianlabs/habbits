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
import 'package:habbits/ui/core/reminder_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotificationService extends NotificationService {
  int syncCalls = 0;
  List<ScheduledReminder> last = const [];
  bool throwOnSync = false;

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> syncSchedule(
    List<ScheduledReminder> reminders, {
    required String body,
  }) async {
    syncCalls++;
    last = reminders;
    if (throwOnSync) throw Exception('boom');
  }
}

Future<Widget> _app(
  AppDatabase db,
  _FakeNotificationService fake,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationServiceProvider.overrideWithValue(fake),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ReminderCoordinator(child: SizedBox()),
    ),
  );
}

void main() {
  testWidgets('syncs reminders for a reminder-enabled habit', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db.habitDao.createHabit(name: 'Read', color: 1);
    await db.habitDao.setReminderTime(id, '23:59');
    final fake = _FakeNotificationService();

    await tester.pumpWidget(await _app(db, fake));
    await tester.pumpAndSettle();

    expect(fake.syncCalls, greaterThan(0));
    expect(fake.last.any((r) => r.habitId == id), isTrue);
  });

  testWidgets('a failing notification service does not crash', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db.habitDao.createHabit(name: 'Read', color: 1);
    await db.habitDao.setReminderTime(id, '23:59');
    final fake = _FakeNotificationService()..throwOnSync = true;

    await tester.pumpWidget(await _app(db, fake));
    await tester.pumpAndSettle();

    expect(fake.syncCalls, greaterThan(0)); // it tried
    expect(tester.takeException(), isNull); // best-effort: error swallowed
  });
}

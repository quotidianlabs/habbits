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
  Future<void> add(String name, int color, List<int> ago, String? rem) async {
    final id = await dao.createHabit(name: name, color: color);
    if (rem != null) await dao.setReminderTime(id, rem);
    for (final d in ago) {
      await dao.toggleCompletion(id, today.subtract(Duration(days: d)));
    }
  }

  await add('Read', 0xFF009688, [0, 1, 2, 3, 5, 6, 8, 9], '21:00');
  await add('Exercise', 0xFFEF5350, [0, 1, 3, 4, 7, 10], '07:30');
  await add('Meditate', 0xFF7E57C2, [1, 2, 4, 6, 9, 12], null);
  await add('Drink water', 0xFF42A5F5, [0, 2, 3, 4, 5, 6, 7, 8], null);
  return db;
}

Future<void> pumpApp(WidgetTester tester, Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final db = await seededDb();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(_NoopNotifications()),
        sharedPreferencesProvider.overrideWithValue(sp),
      ],
      child: const HabbitsApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('README screenshots', (tester) async {
    await pumpApp(tester, {});
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('home-en');

    // Navigate to detail screen by tapping the habit name text
    await tester.tap(find.text('Read').first);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('detail-en');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-tile')));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('settings-en');

    // Dismiss any open dialog/screen before pumping a new app
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpApp(tester, {'locale': 'ru'});
    await tester.pumpAndSettle();
    await binding.takeScreenshot('home-ru');
  });
}

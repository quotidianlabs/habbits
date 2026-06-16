import 'dart:io' show Platform;

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

  // Colors are drawn from kHabitPalette so the shots match the curated picker.
  await add('Read', 0xFF009688, [0, 1, 2, 3, 5, 6, 8, 9], '21:00');
  await add('Exercise', 0xFFE53935, [0, 1, 3, 4, 7, 10], '07:30');
  await add('Meditate', 0xFF5E35B1, [1, 2, 4, 6, 9, 12], null);
  await add('Drink water', 0xFF1E88E5, [0, 2, 3, 4, 5, 6, 7, 8], null);
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
    // Android needs the surface converted to an image once before capturing;
    // iOS captures the native surface directly.
    var surfaceReady = false;
    Future<void> shoot(String name) async {
      if (Platform.isAndroid && !surfaceReady) {
        await binding.convertFlutterSurfaceToImage();
        surfaceReady = true;
      }
      await tester.pumpAndSettle();
      await binding.takeScreenshot(name);
    }

    // --- Light, English ---
    await pumpApp(tester, {'theme': 'light'});
    await shoot('home-en');

    // Detail screen (heatmap + reminder) — tap a habit by name.
    await tester.tap(find.text('Read').first);
    await tester.pumpAndSettle();
    await shoot('detail-en');
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Settings list — now includes the Theme tile alongside Language.
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await shoot('settings-en');
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Color picker — the create dialog with its swatch palette.
    await tester.tap(find.byKey(const Key('add-habit-fab')));
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus(); // hide the keyboard
    await tester.pumpAndSettle();
    await shoot('create-en');

    // --- Russian (fresh app) ---
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpApp(tester, {'locale': 'ru', 'theme': 'light'});
    await shoot('home-ru');

    // --- Dark theme (fresh app) ---
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpApp(tester, {'theme': 'dark'});
    await shoot('home-dark');
  });
}

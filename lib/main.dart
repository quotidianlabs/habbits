import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/repositories/settings_repository.dart';
import 'data/services/notification_service.dart';
import 'l10n/app_localizations.dart';
import 'ui/core/current_day.dart';
import 'ui/core/locale_controller.dart';
import 'ui/core/reminder_coordinator.dart';
import 'ui/core/theme.dart';
import 'ui/core/theme_controller.dart';
import 'ui/habit_list/habit_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notifications = NotificationService();
  await notifications.init();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(notifications),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const HabbitsApp(),
    ),
  );
}

class HabbitsApp extends ConsumerWidget {
  const HabbitsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocale = ref.watch(localeControllerProvider);
    final themeMode = ref.watch(themeControllerProvider);
    return MaterialApp(
      title: 'Habbits',
      debugShowCheckedModeBanner: false,
      theme: habbitsLightTheme(),
      darkTheme: habbitsDarkTheme(),
      themeMode: themeMode.themeMode,
      locale: appLocale.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CurrentDayTicker(
        child: ReminderCoordinator(child: HabitListScreen()),
      ),
    );
  }
}

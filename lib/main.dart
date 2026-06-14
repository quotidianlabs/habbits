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

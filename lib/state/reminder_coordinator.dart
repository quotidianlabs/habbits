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
  ConsumerState<ReminderCoordinator> createState() =>
      _ReminderCoordinatorState();
}

class _ReminderCoordinatorState extends ConsumerState<ReminderCoordinator> {
  AppLifecycleListener? _lifecycle;
  bool _permissionAsked = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _sync);
    // Resync whenever habits/completions change.
    ref.listenManual(habitSummariesProvider, (_, _) => _sync());
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    final summaries = ref.read(habitSummariesProvider).value;
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

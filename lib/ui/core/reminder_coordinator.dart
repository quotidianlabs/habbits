import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/notification_service.dart';
import '../../domain/reminder_schedule.dart';
import '../../l10n/app_localizations.dart';
import '../habit_list/habit_list_view_model.dart';
import 'locale_controller.dart';
import 'notification_permission.dart';
import 'reminder_sync.dart';

/// Watches habits + app lifecycle and forwards change/resume events to a
/// [ReminderSync], which owns the scheduling policy. Renders [child] unchanged.
class ReminderCoordinator extends ConsumerStatefulWidget {
  const ReminderCoordinator({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ReminderCoordinator> createState() =>
      _ReminderCoordinatorState();
}

class _ReminderCoordinatorState extends ConsumerState<ReminderCoordinator> {
  AppLifecycleListener? _lifecycle;
  late final ReminderSync _sync;

  @override
  void initState() {
    super.initState();
    _sync = ReminderSync(
      service: ref.read(notificationServiceProvider),
      readEnabledHabits: _readEnabledHabits,
      readBody: () => AppLocalizations.of(context).reminderBody,
      reportPermission: (granted) =>
          ref.read(notificationPermissionProvider.notifier).report(granted),
      isActive: () => mounted,
    );
    _lifecycle = AppLifecycleListener(onResume: _sync.onResume);
    // Resync whenever habits/completions or the locale change.
    ref.listenManual(habitListViewModelProvider, (_, _) => _sync.sync());
    ref.listenManual(localeControllerProvider, (_, _) => _sync.sync());
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync.sync());
  }

  /// Current reminder-enabled habits, or null while the summaries stream has
  /// not produced a value yet (skip the sync rather than cancel everything).
  List<ReminderHabit>? _readEnabledHabits() {
    final summaries = ref.read(habitListViewModelProvider).value;
    if (summaries == null) return null;
    return [
      for (final s in summaries)
        if (s.habit.reminderTime != null)
          ReminderHabit(
            id: s.habit.id,
            name: s.habit.name,
            time: s.habit.reminderTime!,
            doneToday: s.doneToday,
          ),
    ];
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

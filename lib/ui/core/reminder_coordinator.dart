import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/notification_service.dart';
import '../../domain/reminder_schedule.dart';
import '../../l10n/app_localizations.dart';
import '../habit_list/habit_list_view_model.dart';
import 'coalescing_runner.dart';
import 'locale_controller.dart';
import 'notification_permission.dart';

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
  final _runner = CoalescingRunner();
  bool _permissionAsked = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _resyncWithTimeZone);
    // Resync whenever habits/completions change.
    ref.listenManual(habitListViewModelProvider, (_, _) => _sync());
    ref.listenManual(localeControllerProvider, (_, _) => _sync());
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  /// Serialized so overlapping triggers can't interleave a `cancelAll()` +
  /// reschedule, and best-effort so a plugin failure doesn't escape as an
  /// unhandled async error.
  Future<void> _sync() => _runner.run(_runSyncSafe);

  /// On resume, re-resolve the device timezone (it may have changed while away)
  /// before resyncing, so reminders follow the device after travel.
  Future<void> _resyncWithTimeZone() => _runner.run(() async {
    try {
      await ref.read(notificationServiceProvider).refreshTimeZone();
    } catch (_) {
      // Best-effort; fall through to the resync regardless.
    }
    await _runSyncSafe();
  });

  Future<void> _runSyncSafe() async {
    try {
      await _runSync();
    } catch (_) {
      // Reminder scheduling is best-effort; swallow plugin/platform failures.
    }
  }

  Future<void> _runSync() async {
    final summaries = ref.read(habitListViewModelProvider).value;
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
    if (enabled.isNotEmpty) {
      if (!_permissionAsked) {
        _permissionAsked = true;
        await service.requestPermission();
      }
      final granted = await service.hasPermission();
      if (!mounted) return;
      ref.read(notificationPermissionProvider.notifier).set(granted);
    }
    if (!mounted) return;
    final body = AppLocalizations.of(context).reminderBody;
    await service.syncSchedule(
      computeReminderSchedule(enabled, DateTime.now()),
      body: body,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

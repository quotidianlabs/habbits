import '../../data/services/notification_service.dart';
import '../../domain/reminder_schedule.dart';
import 'coalescing_runner.dart';

/// The reminder-scheduling *policy*, extracted from [ReminderCoordinator] so it
/// is unit-testable without pumping a widget. Plain Dart: no Flutter, no
/// Riverpod. Collaborators are injected as callbacks so the widget owns all
/// `ref`/`context` access.
///
/// Owns the serialization (so a `cancelAll()` + reschedule can't interleave),
/// the once-only permission prompt, and the two order-sensitive sequences.
class ReminderSync {
  ReminderSync({
    required this.service,
    required this.readEnabledHabits,
    required this.readBody,
    required this.reportPermission,
    required this.isActive,
    this.now = DateTime.now,
  });

  final NotificationService service;

  /// Current reminder-enabled habits, or null while summaries aren't ready yet
  /// (skip the sync rather than cancel everything).
  final List<ReminderHabit>? Function() readEnabledHabits;

  /// The localized notification body text.
  final String Function() readBody;

  /// Records the latest observed permission status.
  final void Function(bool granted) reportPermission;

  /// Whether the owner is still live (≈ widget `mounted`); guards writes that run
  /// after an `await`, so a post-dispose completion can't touch a dead owner.
  final bool Function() isActive;

  final DateTime Function() now;

  final _runner = CoalescingRunner();
  bool _permissionAsked = false;

  /// Coalesced, best-effort resync — the post-frame / habit-change / locale path.
  Future<void> sync() => _runner.run(_runSyncSafe);

  /// On resume, re-resolve the device timezone (it may have changed while away)
  /// and re-check permission (the user may have toggled it in system settings)
  /// before resyncing — both only happen here, not on every sync.
  Future<void> onResume() => _runner.run(() async {
    try {
      await service.refreshTimeZone();
      if (_permissionAsked) await _updatePermission();
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
    final enabled = readEnabledHabits();
    if (enabled == null) return; // summaries not ready yet

    // Prompt + record permission once (the first sync with reminders); thereafter
    // it's only re-checked on resume. requestPermission() must run before
    // hasPermission() — on iOS a fresh "not determined" state reads as disabled
    // until the prompt resolves.
    if (enabled.isNotEmpty && !_permissionAsked) {
      _permissionAsked = true;
      await service.requestPermission();
      await _updatePermission();
    }
    if (!isActive()) return;
    await service.syncSchedule(
      computeReminderSchedule(enabled, now()),
      body: readBody(),
    );
  }

  Future<void> _updatePermission() async {
    final granted = await service.hasPermission();
    if (!isActive()) return;
    reportPermission(granted);
  }
}

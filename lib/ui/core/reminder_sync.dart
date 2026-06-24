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
    required NotificationService service,
    required List<ReminderHabit>? Function() readEnabledHabits,
    required String Function() readBody,
    required void Function(bool granted) reportPermission,
    required bool Function() isActive,
    DateTime Function() now = DateTime.now,
  }) : _service = service,
       _readEnabledHabits = readEnabledHabits,
       _readBody = readBody,
       _reportPermission = reportPermission,
       _isActive = isActive,
       _now = now;

  final NotificationService _service;
  final List<ReminderHabit>? Function() _readEnabledHabits;
  final String Function() _readBody;
  final void Function(bool granted) _reportPermission;
  final bool Function() _isActive;
  final DateTime Function() _now;

  final _runner = CoalescingRunner();
  bool _permissionAsked = false;

  /// Coalesced, best-effort resync — the post-frame / habit-change / locale path.
  Future<void> sync() => _runner.run(_runSyncSafe);

  /// On resume, re-resolve the device timezone (it may have changed while away)
  /// and re-check permission (the user may have toggled it in system settings)
  /// before resyncing — both only happen here, not on every sync.
  Future<void> onResume() => _runner.run(() async {
    try {
      await _service.refreshTimeZone();
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
    final enabled = _readEnabledHabits();
    if (enabled == null) return; // summaries not ready yet

    // Prompt + record permission once (the first sync with reminders); thereafter
    // it's only re-checked on resume. requestPermission() must run before
    // hasPermission() — on iOS a fresh "not determined" state reads as disabled
    // until the prompt resolves.
    if (enabled.isNotEmpty && !_permissionAsked) {
      _permissionAsked = true;
      await _service.requestPermission();
      await _updatePermission();
    }
    if (!_isActive()) return;
    await _service.syncSchedule(
      computeReminderSchedule(enabled, _now()),
      body: _readBody(),
    );
  }

  Future<void> _updatePermission() async {
    final granted = await _service.hasPermission();
    if (!_isActive()) return;
    _reportPermission(granted);
  }
}

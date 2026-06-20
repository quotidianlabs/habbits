import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_permission.g.dart';

/// Whether the OS currently permits notifications: `true` granted, `false`
/// denied, `null` not yet known. The [ReminderCoordinator] sets it after the
/// one-time prompt and on each resync; Settings watches it to warn when reminders
/// are enabled but won't fire. Default `null` means no coordinator has reported
/// yet — Settings shows no warning.
@Riverpod(keepAlive: true)
class NotificationPermission extends _$NotificationPermission {
  @override
  bool? build() => null;

  /// Records the latest observed permission status (from the coordinator).
  void report(bool granted) => state = granted;
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_permission.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the OS currently permits notifications: `true` granted, `false`
/// denied, `null` not yet known. The [ReminderCoordinator] sets it after the
/// one-time prompt and on each resync; Settings watches it to warn when reminders
/// are enabled but won't fire. Default `null` means no coordinator has reported
/// yet — Settings shows no warning.

@ProviderFor(NotificationPermission)
final notificationPermissionProvider = NotificationPermissionProvider._();

/// Whether the OS currently permits notifications: `true` granted, `false`
/// denied, `null` not yet known. The [ReminderCoordinator] sets it after the
/// one-time prompt and on each resync; Settings watches it to warn when reminders
/// are enabled but won't fire. Default `null` means no coordinator has reported
/// yet — Settings shows no warning.
final class NotificationPermissionProvider
    extends $NotifierProvider<NotificationPermission, bool?> {
  /// Whether the OS currently permits notifications: `true` granted, `false`
  /// denied, `null` not yet known. The [ReminderCoordinator] sets it after the
  /// one-time prompt and on each resync; Settings watches it to warn when reminders
  /// are enabled but won't fire. Default `null` means no coordinator has reported
  /// yet — Settings shows no warning.
  NotificationPermissionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationPermissionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationPermissionHash();

  @$internal
  @override
  NotificationPermission create() => NotificationPermission();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool?>(value),
    );
  }
}

String _$notificationPermissionHash() =>
    r'4ccf7af90949340b0664555c41cef05c6b59a795';

/// Whether the OS currently permits notifications: `true` granted, `false`
/// denied, `null` not yet known. The [ReminderCoordinator] sets it after the
/// one-time prompt and on each resync; Settings watches it to warn when reminders
/// are enabled but won't fire. Default `null` means no coordinator has reported
/// yet — Settings shows no warning.

abstract class _$NotificationPermission extends $Notifier<bool?> {
  bool? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool?, bool?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool?, bool?>,
              bool?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

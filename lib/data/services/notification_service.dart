import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/reminder_schedule.dart';

part 'notification_service.g.dart';

/// The local wall-clock instant for [when]'s date and time-of-day in `tz.local`.
/// Built directly (not via `TZDateTime.from`, which would preserve the absolute
/// instant of a VM-local `DateTime`) so a reminder fires at the chosen `HH:mm`
/// every day, including across a DST transition.
tz.TZDateTime scheduledInstant(DateTime when) => tz.TZDateTime(
  tz.local,
  when.year,
  when.month,
  when.day,
  when.hour,
  when.minute,
);

/// Wraps flutter_local_notifications + timezone for on-device habit reminders.
/// The plugin boundary; all decision logic lives in computeReminderSchedule.
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  static const _channelId = 'habit_reminders';

  Future<void> init() async {
    tzdata.initializeTimeZones();
    await refreshTimeZone();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    // v22: initialize() takes settings as a named parameter.
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: darwin),
    );
    // The Android channel is (re)created in syncSchedule with the localized
    // name, so it isn't created here (no BuildContext at init).
  }

  /// Re-resolves the device's IANA zone into `tz.local`. Called at init and on
  /// app resume so reminders follow the device after a timezone change (travel).
  Future<void> refreshTimeZone() async {
    // flutter_timezone 5.x returns TimezoneInfo (not String); use .identifier.
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
  }

  /// Whether notifications are currently permitted — a check, not a prompt.
  /// Defaults to true on a platform that exposes neither query (don't nag).
  ///
  /// The iOS resolver returns null off-iOS, so a non-null result means iOS; on
  /// iOS `isEnabled` reads false for the "not determined" state, so callers must
  /// prompt (`requestPermission`) before relying on this. Mirrors the
  /// resolve-iOS-then-Android pattern in [requestPermission].
  Future<bool> hasPermission() async {
    final ios = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.checkPermissions();
    if (ios != null) return ios.isEnabled;
    final android = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.areNotificationsEnabled();
    return android ?? true;
  }

  /// Asks the OS for notification permission. Returns true if granted.
  Future<bool> requestPermission() async {
    final ios = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    final android = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    return ios ?? android ?? false;
  }

  /// Cancels everything and reschedules exactly [reminders]. [channelName] is
  /// the localized Android channel label (shown in system settings); the channel
  /// is (re)created with it on every sync, so it follows the app locale — the
  /// reminder coordinator resyncs on locale change.
  Future<void> syncSchedule(
    List<ScheduledReminder> reminders, {
    required String body,
    required String channelName,
  }) async {
    await _plugin.cancelAll();
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          AndroidNotificationChannel(_channelId, channelName),
        );
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        channelName,
        importance: Importance.defaultImportance,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    for (var i = 0; i < reminders.length; i++) {
      final r = reminders[i];
      // v22 zonedSchedule: title/body are named optional params; no
      // uiLocalNotificationDateInterpretation; androidScheduleMode is required.
      await _plugin.zonedSchedule(
        id: i,
        title: r.habitName,
        body: body,
        scheduledDate: scheduledInstant(r.when),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}

@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) => throw UnimplementedError(
  'notificationServiceProvider must be overridden in main',
);

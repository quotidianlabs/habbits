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
  static const _channelName = 'Habit reminders';

  Future<void> init() async {
    tzdata.initializeTimeZones();
    // flutter_timezone 5.x returns TimezoneInfo (not String); use .identifier.
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));

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

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(_channelId, _channelName),
        );
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

  /// Cancels everything and reschedules exactly [reminders].
  Future<void> syncSchedule(
    List<ScheduledReminder> reminders, {
    required String body,
  }) async {
    await _plugin.cancelAll();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.defaultImportance,
      ),
      iOS: DarwinNotificationDetails(),
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

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminder_schedule.dart';

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
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(_channelId, _channelName),
        );
  }

  /// Asks the OS for notification permission. Returns true if granted.
  Future<bool> requestPermission() async {
    final ios = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    final android = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    return ios ?? android ?? false;
  }

  /// Cancels everything and reschedules exactly [reminders].
  Future<void> syncSchedule(List<ScheduledReminder> reminders) async {
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
        body: 'Time to check in',
        scheduledDate: tz.TZDateTime.from(r.when, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}

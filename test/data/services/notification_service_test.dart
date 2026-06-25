import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/services/notification_service.dart';
import 'package:habbits/domain/reminder_schedule.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class _MockAndroid extends Mock
    implements AndroidFlutterLocalNotificationsPlugin {}

class _MockIOS extends Mock implements IOSFlutterLocalNotificationsPlugin {}

class _MockEnabledOptions extends Mock implements NotificationsEnabledOptions {}

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));

    registerFallbackValue(const InitializationSettings());
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(const AndroidNotificationChannel('x', 'x'));
    registerFallbackValue(AndroidScheduleMode.inexactAllowWhileIdle);
    registerFallbackValue(tz.TZDateTime(tz.local, 2026));
  });

  // Helper: mock the flutter_timezone method channel to return [id].
  // flutter_timezone 5.x: channel name is 'flutter_timezone'; a bare String
  // return is accepted and wrapped into TimezoneInfo(identifier: id).
  void mockTimezone(String id) {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_timezone'),
          (MethodCall call) async => id,
        );
  }

  void clearTimezone() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_timezone'),
          null,
        );
  }

  test('scheduledInstant preserves wall-clock HH:mm in tz.local across DST', () {
    // US spring-forward is 2026-03-08. A 09:00 reminder must fire at 09:00 local
    // on both sides of the transition (wall-clock preserved, not the instant).
    final before = scheduledInstant(DateTime(2026, 3, 7, 9, 0));
    final after = scheduledInstant(DateTime(2026, 3, 9, 9, 0));
    expect(before.hour, 9);
    expect(after.hour, 9);
    expect(before.location, tz.local);
    expect(after.location, tz.local);
  });

  test('refreshTimeZone resolves the device zone into tz.local', () async {
    mockTimezone('Europe/Moscow');
    addTearDown(clearTimezone);

    await NotificationService(_MockPlugin()).refreshTimeZone();

    expect(tz.local.name, 'Europe/Moscow');
  });

  group('android plugin boundary', () {
    late _MockPlugin plugin;
    late _MockAndroid android;

    setUp(() {
      plugin = _MockPlugin();
      android = _MockAndroid();
      // Android present, iOS absent → android branch.
      when(
        () => plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >(),
      ).thenReturn(android);
      when(
        () => plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >(),
      ).thenReturn(null);
    });

    test('init initializes the plugin and creates the channel', () async {
      mockTimezone('America/New_York');
      addTearDown(clearTimezone);

      when(
        () => plugin.initialize(settings: any(named: 'settings')),
      ).thenAnswer((_) async => true);
      when(
        () => android.createNotificationChannel(any()),
      ).thenAnswer((_) async {});

      await NotificationService(plugin).init();

      verify(
        () => plugin.initialize(settings: any(named: 'settings')),
      ).called(1);
      verify(() => android.createNotificationChannel(any())).called(1);
    });

    test('hasPermission reads areNotificationsEnabled', () async {
      when(
        () => android.areNotificationsEnabled(),
      ).thenAnswer((_) async => true);

      expect(await NotificationService(plugin).hasPermission(), isTrue);
    });

    test('requestPermission requests the android permission', () async {
      when(
        () => android.requestNotificationsPermission(),
      ).thenAnswer((_) async => true);

      expect(await NotificationService(plugin).requestPermission(), isTrue);
    });

    test('syncSchedule cancels all then schedules one per reminder', () async {
      when(() => plugin.cancelAll()).thenAnswer((_) async {});
      when(
        () => plugin.zonedSchedule(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledDate: any(named: 'scheduledDate'),
          notificationDetails: any(named: 'notificationDetails'),
          androidScheduleMode: any(named: 'androidScheduleMode'),
        ),
      ).thenAnswer((_) async {});

      await NotificationService(plugin).syncSchedule([
        ScheduledReminder(
          habitId: 1,
          habitName: 'Read',
          when: DateTime(2026, 6, 25, 20),
        ),
        ScheduledReminder(
          habitId: 2,
          habitName: 'Walk',
          when: DateTime(2026, 6, 25, 21),
        ),
      ], body: 'time!');

      // Verify order: cancelAll first, then two zonedSchedule calls.
      verifyInOrder([
        () => plugin.cancelAll(),
        () => plugin.zonedSchedule(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledDate: any(named: 'scheduledDate'),
          notificationDetails: any(named: 'notificationDetails'),
          androidScheduleMode: any(named: 'androidScheduleMode'),
        ),
        () => plugin.zonedSchedule(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledDate: any(named: 'scheduledDate'),
          notificationDetails: any(named: 'notificationDetails'),
          androidScheduleMode: any(named: 'androidScheduleMode'),
        ),
      ]);
    });

    test('cancelAll cancels everything', () async {
      when(() => plugin.cancelAll()).thenAnswer((_) async {});

      await NotificationService(plugin).cancelAll();

      verify(() => plugin.cancelAll()).called(1);
    });
  });

  group('ios plugin boundary', () {
    late _MockPlugin plugin;
    late _MockIOS ios;

    setUp(() {
      plugin = _MockPlugin();
      ios = _MockIOS();
      when(
        () => plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >(),
      ).thenReturn(ios);
    });

    test('hasPermission returns the ios isEnabled', () async {
      final opts = _MockEnabledOptions();
      when(() => opts.isEnabled).thenReturn(true);
      when(() => ios.checkPermissions()).thenAnswer((_) async => opts);

      expect(await NotificationService(plugin).hasPermission(), isTrue);
    });

    test('requestPermission requests the ios permissions', () async {
      when(
        () => ios.requestPermissions(
          alert: any(named: 'alert'),
          badge: any(named: 'badge'),
          sound: any(named: 'sound'),
        ),
      ).thenAnswer((_) async => true);

      expect(await NotificationService(plugin).requestPermission(), isTrue);
    });
  });

  test('notificationServiceProvider throws until overridden in main', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(notificationServiceProvider),
      throwsA(
        isA<Object>().having(
          (e) => e.toString(),
          'message',
          contains('must be overridden in main'),
        ),
      ),
    );
  });
}

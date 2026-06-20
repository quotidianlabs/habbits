import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));
  });

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
}

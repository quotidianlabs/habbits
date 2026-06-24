import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/services/notification_service.dart';
import 'package:habbits/domain/reminder_schedule.dart';
import 'package:habbits/ui/core/reminder_sync.dart';

/// Records call order and counts; lets a test block `syncSchedule` to force
/// overlapping runs, throw from it, and choose the permission result.
class _FakeService extends NotificationService {
  final List<String> calls = [];
  int syncCalls = 0;
  bool permission = true;
  bool throwOnSync = false;
  Completer<void>? blockSync;

  @override
  Future<bool> requestPermission() async {
    calls.add('request');
    return permission;
  }

  @override
  Future<bool> hasPermission() async {
    calls.add('check');
    return permission;
  }

  @override
  Future<void> refreshTimeZone() async => calls.add('refresh');

  @override
  Future<void> syncSchedule(
    List<ScheduledReminder> reminders, {
    required String body,
  }) async {
    calls.add('schedule');
    syncCalls++;
    if (blockSync != null) await blockSync!.future;
    if (throwOnSync) throw Exception('boom');
  }
}

const _oneHabit = [
  ReminderHabit(id: 1, name: 'Read', time: '23:59', doneToday: false),
];

void main() {
  ReminderSync build(
    _FakeService fake, {
    List<ReminderHabit>? Function()? readEnabledHabits,
    bool Function()? isActive,
    void Function(bool)? reportPermission,
  }) => ReminderSync(
    service: fake,
    readEnabledHabits: readEnabledHabits ?? () => _oneHabit,
    readBody: () => 'body',
    reportPermission: reportPermission ?? (_) {},
    isActive: isActive ?? () => true,
    now: () => DateTime(2026, 6, 13, 8, 0),
  );

  test('first sync requests permission before checking, then reports', () async {
    final fake = _FakeService();
    bool? reported;
    final sync = build(fake, reportPermission: (g) => reported = g);

    await sync.sync();

    expect(fake.calls, ['request', 'check', 'schedule']);
    expect(reported, isTrue);
  });

  test('permission prompt fires only once across syncs', () async {
    final fake = _FakeService();
    final sync = build(fake);

    await sync.sync();
    await sync.sync();

    expect(fake.calls.where((c) => c == 'request'), hasLength(1));
  });

  test('onResume refreshes the timezone, re-checks, then resyncs', () async {
    final fake = _FakeService();
    final sync = build(fake);

    await sync.sync(); // arms the permission gate
    fake.calls.clear();

    await sync.onResume();

    expect(fake.calls, ['refresh', 'check', 'schedule']);
  });

  test('onResume on a fresh controller still does the first-time prompt', () async {
    final fake = _FakeService();
    final sync = build(fake);

    await sync.onResume();

    // No onResume-level re-check (gate unarmed), but _runSync does the one-time
    // request+check; contrast the armed case above, which has no 'request'.
    expect(fake.calls, ['refresh', 'request', 'check', 'schedule']);
  });

  test('overlapping syncs coalesce instead of interleaving', () async {
    final fake = _FakeService()..blockSync = Completer<void>();
    final sync = build(fake);

    final first = sync.sync(); // enters syncSchedule and blocks
    await Future<void>.delayed(Duration.zero);
    // Three more triggers while the first is in flight -> one coalesced run.
    final extras = Future.wait([sync.sync(), sync.sync(), sync.sync()]);

    fake.blockSync!.complete();
    await first;
    await extras;

    expect(fake.syncCalls, 2); // the in-flight run + a single coalesced run
  });

  test('a throwing syncSchedule does not escape', () async {
    final fake = _FakeService()..throwOnSync = true;
    final sync = build(fake);

    await expectLater(sync.sync(), completes);
    expect(fake.syncCalls, 1);
  });

  test('isActive false suppresses the report and the schedule', () async {
    final fake = _FakeService();
    var reported = false;
    final sync = build(
      fake,
      isActive: () => false,
      reportPermission: (_) => reported = true,
    );

    await sync.sync();

    expect(reported, isFalse);
    expect(fake.syncCalls, 0);
    expect(fake.calls, isNot(contains('schedule')));
  });

  test('null enabled list (summaries not ready) skips entirely', () async {
    final fake = _FakeService();
    final sync = build(fake, readEnabledHabits: () => null);

    await sync.sync();

    expect(fake.calls, isEmpty);
    expect(fake.syncCalls, 0);
  });
}

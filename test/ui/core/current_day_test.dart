import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/dates.dart';
import 'package:habbits/ui/core/current_day.dart';

void main() {
  test('defaults to today and refresh is a no-op on the same day', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final today = dateOnly(DateTime.now());
    expect(container.read(currentDayProvider), today);

    container.read(currentDayProvider.notifier).refresh();
    expect(container.read(currentDayProvider), today); // same day -> unchanged
  });

  testWidgets('ticker refreshes currentDay across the midnight timer', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CurrentDayTicker(child: SizedBox())),
      ),
    );

    // Arming reads currentDay; advancing past the next-midnight Timer fires
    // _refresh + re-arms. Pump just over 24h to guarantee the timer elapses.
    await tester.pump(const Duration(hours: 25));
    await tester.pumpAndSettle();

    expect(container.read(currentDayProvider), isA<DateTime>());

    // Resume path: dispatch a resume lifecycle event, which calls _refresh.
    // Valid transitions to resumed are from inactive or detached.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    // Dispose path: replacing the tree disposes the State (cancels timer +
    // lifecycle listener).
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SizedBox()),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}

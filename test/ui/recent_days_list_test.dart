import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/ui/widgets/recent_days_list.dart';

void main() {
  final today = DateTime(2026, 6, 13);

  Widget host({required void Function(DateTime) onToggle, Set<DateTime> done = const {}}) =>
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecentDaysList(
              completed: done,
              today: today,
              count: 5,
              onToggle: onToggle,
            ),
          ),
        ),
      );

  testWidgets('lists the last N days newest-first with today labeled', (tester) async {
    await tester.pumpWidget(host(onToggle: (_) {}, done: {DateTime(2026, 6, 12)}));
    expect(find.textContaining('Today'), findsOneWidget);
    expect(find.byKey(const Key('daylist-2026-06-13')), findsOneWidget); // today
    expect(find.byKey(const Key('daylist-2026-06-09')), findsOneWidget); // today-4
    expect(find.byKey(const Key('daylist-2026-06-08')), findsNothing);   // outside window
  });

  testWidgets('tapping a row calls onToggle with that date', (tester) async {
    DateTime? toggled;
    await tester.pumpWidget(host(onToggle: (d) => toggled = d));
    await tester.tap(find.byKey(const Key('daylist-2026-06-11')));
    expect(toggled, DateTime(2026, 6, 11));
  });
}

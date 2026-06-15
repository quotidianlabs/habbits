import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/ui/widgets/day_strip.dart';

void main() {
  testWidgets('renders one keyed cell per day in the window', (tester) async {
    final today = DateTime(2026, 6, 13);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DayStrip(
            completed: {DateTime(2026, 6, 12)},
            today: today,
            color: Colors.teal,
            count: 14,
          ),
        ),
      ),
    );
    expect(
      find.byKey(const Key('daystrip-2026-06-13')),
      findsOneWidget,
    ); // today
    expect(
      find.byKey(const Key('daystrip-2026-05-31')),
      findsOneWidget,
    ); // today-13
    expect(
      find.byKey(const Key('daystrip-2026-05-30')),
      findsNothing,
    ); // today-14
  });
}

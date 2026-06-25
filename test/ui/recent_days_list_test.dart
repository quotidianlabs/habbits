import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/l10n/app_localizations.dart';
import 'package:habbits/ui/widgets/recent_days_list.dart';
import 'package:intl/intl.dart';

void main() {
  final defaultToday = DateTime(2026, 6, 13);

  Widget host({
    required void Function(DateTime) onToggle,
    Set<DateTime> done = const {},
    DateTime? today,
    Locale? locale,
  }) => MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: RecentDaysList(
          completed: done,
          today: today ?? defaultToday,
          count: 5,
          onToggle: onToggle,
        ),
      ),
    ),
  );

  testWidgets('lists the last N days newest-first with today labeled', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(onToggle: (_) {}, done: {DateTime(2026, 6, 12)}),
    );
    expect(find.textContaining('Today'), findsOneWidget);
    expect(
      find.byKey(const Key('daylist-2026-06-13')),
      findsOneWidget,
    ); // today
    expect(
      find.byKey(const Key('daylist-2026-06-09')),
      findsOneWidget,
    ); // today-4
    expect(
      find.byKey(const Key('daylist-2026-06-08')),
      findsNothing,
    ); // outside window
  });

  testWidgets('tapping a row calls onToggle with that date', (tester) async {
    DateTime? toggled;
    await tester.pumpWidget(host(onToggle: (d) => toggled = d));
    await tester.tap(find.byKey(const Key('daylist-2026-06-11')));
    expect(toggled, DateTime(2026, 6, 11));
  });

  testWidgets('formats the today row in Russian', (tester) async {
    final today = DateTime(2026, 6, 12); // Friday
    await tester.pumpWidget(
      host(
        onToggle: (_) {},
        done: const {},
        today: today,
        locale: const Locale('ru'),
      ),
    );
    await tester.pumpAndSettle();
    final base = DateFormat.MMMEd('ru').format(today);
    expect(find.text('Сегодня · $base'), findsOneWidget);
    // A non-today row renders the bare formatted date, no prefix.
    final yesterday = DateTime(2026, 6, 11);
    expect(find.text(DateFormat.MMMEd('ru').format(yesterday)), findsOneWidget);
  });

  testWidgets('tapping a day checkbox invokes onToggle with that date', (
    tester,
  ) async {
    DateTime? toggled;
    await tester.pumpWidget(host(onToggle: (d) => toggled = d));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first); // onChanged → line 51
    await tester.pumpAndSettle();

    expect(toggled, isNotNull);
  });
}

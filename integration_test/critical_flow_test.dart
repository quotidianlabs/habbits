import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:habbits/data/services/database/database.dart';
import 'package:habbits/data/services/database/database_providers.dart';
import 'package:habbits/l10n/app_localizations.dart';
import 'package:habbits/ui/habit_list/habit_list_screen.dart';

/// Pumps frames until [finder] matches at least one widget, or [timeout]
/// elapses. Needed because check-off writes through the real on-device SQLite
/// database asynchronously: the write → Drift stream re-emit → rebuild happens
/// on the event loop, which `pumpAndSettle` does not wait for.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TimeoutException('Timed out waiting for $finder after $timeout');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Widget appWith(AppDatabase db) => ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: HabitListScreen(),
    ),
  );

  testWidgets('create, check off, streak=1, persists across relaunch', (
    tester,
  ) async {
    // A single file-backed (on-device) database, shared across two "launches".
    final db = AppDatabase();
    // Start clean in case a prior run left data.
    await db.delete(db.habits).go();

    // --- Launch 1 ---
    await tester.pumpWidget(appWith(db));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-habit-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('habit-name-field')),
      'Medicine',
    );
    await tester.tap(find.byKey(const Key('habit-name-confirm')));
    await pumpUntilFound(tester, find.text('Medicine'));

    await tester.tap(find.byType(Checkbox));
    await pumpUntilFound(tester, find.text('Streak: 1'));

    expect(find.text('Medicine'), findsOneWidget);
    expect(find.text('Streak: 1'), findsOneWidget);
    await db.close();

    // --- Launch 2 (relaunch): reopen the same on-disk database ---
    final reopened = AppDatabase();
    addTearDown(reopened.close);
    await tester.pumpWidget(appWith(reopened));
    await pumpUntilFound(tester, find.text('Streak: 1'));

    expect(find.text('Medicine'), findsOneWidget);
    expect(find.text('Streak: 1'), findsOneWidget);

    // Cleanup so reruns stay deterministic.
    await reopened.delete(reopened.habits).go();
  });
}

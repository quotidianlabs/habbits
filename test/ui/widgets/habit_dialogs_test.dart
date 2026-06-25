import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/l10n/app_localizations.dart';
import 'package:habbits/ui/core/habit_colors.dart';
import 'package:habbits/ui/widgets/habit_dialogs.dart';

void main() {
  testWidgets('returns entered name and chosen swatch', (tester) async {
    HabitFormResult? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open'),
              onPressed: () async {
                result = await showHabitNameDialog(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('habit-name-field')), 'Run');
    final second = kHabitPalette[1];
    await tester.tap(
      find.byKey(Key('habit-color-${second.toRadixString(16)}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('habit-name-confirm')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.name, 'Run');
    expect(result!.color, second);
  });

  testWidgets('submitting an empty name pops without a result', (tester) async {
    HabitFormResult? result;
    var popped = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open'),
              onPressed: () async {
                result = await showHabitNameDialog(context);
                popped = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    // Leave the name field empty and confirm → early Navigator.pop (line 61).
    await tester.tap(find.byKey(const Key('habit-name-confirm')));
    await tester.pumpAndSettle();

    expect(popped, isTrue);
    expect(result, isNull);
  });

  testWidgets('pressing done on the name field submits (onSubmitted)', (
    tester,
  ) async {
    HabitFormResult? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open'),
              onPressed: () async {
                result = await showHabitNameDialog(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('habit-name-field')), 'Run');
    await tester.testTextInput.receiveAction(TextInputAction.done); // line 81
    await tester.pumpAndSettle();

    expect(result?.name, 'Run');
  });

  testWidgets('tapping cancel on the name dialog pops without a result', (
    tester,
  ) async {
    HabitFormResult? result;
    var popped = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open'),
              onPressed: () async {
                result = await showHabitNameDialog(context);
                popped = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel')); // l10n.cancel → line 116
    await tester.pumpAndSettle();

    expect(popped, isTrue);
    expect(result, isNull);
  });

  testWidgets('confirmDeleteHabit returns false on cancel, true on confirm', (
    tester,
  ) async {
    final results = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open'),
              onPressed: () async =>
                  results.add(await confirmDeleteHabit(context, 'Read')),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel')); // l10n.cancel → line 116
    await tester.pumpAndSettle();
    expect(results.single, isFalse);

    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete'))); // line 140
    await tester.pumpAndSettle();
    expect(results.last, isTrue);
  });
}

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
}

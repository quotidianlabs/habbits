import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/heatmap.dart';
import 'package:habbits/ui/widgets/heatmap_grid.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(initializeDateFormatting);

  // A 6-week span crossing May -> June 2026 (May 4 is a Monday).
  HeatmapData multiMonth() {
    final weeks = <List<HeatmapCell>>[];
    var monday = DateTime(2026, 5, 4);
    for (var w = 0; w < 6; w++) {
      final week = <HeatmapCell>[];
      for (var i = 0; i < 7; i++) {
        final d = DateTime(monday.year, monday.month, monday.day + i);
        week.add(HeatmapCell(d, CellState.notCompleted));
      }
      weeks.add(week);
      monday = DateTime(monday.year, monday.month, monday.day + 7);
    }
    return HeatmapData(weeks);
  }

  test('monthLabels places the label on the column containing the 1st', () {
    // July 1 2026 is a Wednesday, so it falls mid-column (not on the Monday).
    final data = buildHeatmap(
      completed: const {},
      today: DateTime(2026, 7, 5),
      weeks: 6,
    );
    final labels = monthLabels(data.weeks, 'en');
    final julCol = data.weeks.indexWhere(
      (w) => w.any((c) => c.date == DateTime(2026, 7, 1)),
    );
    expect(julCol, isNonNegative);
    expect(labels[julCol], 'Jul'); // not the column to its right
  });

  testWidgets('renders a keyed cell per day', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: HeatmapGrid(data: multiMonth(), color: Colors.teal),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('heatmap-cell-2026-06-08')), findsOneWidget);
  });

  testWidgets('showMonthLabels renders month abbreviations across the span', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: HeatmapGrid(
              data: multiMonth(),
              color: Colors.teal,
              showMonthLabels: true,
            ),
          ),
        ),
      ),
    );
    expect(find.text('May'), findsOneWidget);
    expect(find.text('Jun'), findsOneWidget);
  });

  testWidgets('default has no month labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: HeatmapGrid(data: multiMonth(), color: Colors.teal),
          ),
        ),
      ),
    );
    expect(find.text('May'), findsNothing);
    expect(find.text('Jun'), findsNothing);
  });

  testWidgets('renders under a dark theme without error', (tester) async {
    final data = buildHeatmap(
      completed: {DateTime(2026, 6, 10)},
      today: DateTime(2026, 6, 15),
      weeks: 2,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: Scaffold(
          body: HeatmapGrid(data: data, color: const Color(0xFF009688)),
        ),
      ),
    );
    expect(find.byType(HeatmapGrid), findsOneWidget);
  });
}

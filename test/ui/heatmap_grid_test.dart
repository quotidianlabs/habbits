import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/heatmap.dart';
import 'package:habbits/ui/widgets/heatmap_grid.dart';

void main() {
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

  testWidgets('renders a keyed cell per day', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: HeatmapGrid(data: multiMonth(), color: Colors.teal),
        ),
      ),
    ));
    expect(find.byKey(const Key('heatmap-cell-2026-06-08')), findsOneWidget);
  });

  testWidgets('showMonthLabels renders month abbreviations across the span',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
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
    ));
    expect(find.text('May'), findsOneWidget);
    expect(find.text('Jun'), findsOneWidget);
  });

  testWidgets('default has no month labels', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: HeatmapGrid(data: multiMonth(), color: Colors.teal),
        ),
      ),
    ));
    expect(find.text('May'), findsNothing);
    expect(find.text('Jun'), findsNothing);
  });
}

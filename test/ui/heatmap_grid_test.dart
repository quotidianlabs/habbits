import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/heatmap.dart';
import 'package:habbits/ui/widgets/heatmap_grid.dart';

HeatmapData _oneWeek() {
  // Mon..Sun with a known mix of states.
  final monday = DateTime(2026, 6, 8);
  DateTime d(int i) => DateTime(monday.year, monday.month, monday.day + i);
  return HeatmapData([
    [
      HeatmapCell(d(0), CellState.completed),
      HeatmapCell(d(1), CellState.notCompleted),
      HeatmapCell(d(2), CellState.notCompleted),
      HeatmapCell(d(3), CellState.notCompleted),
      HeatmapCell(d(4), CellState.notCompleted),
      HeatmapCell(d(5), CellState.notCompleted),
      HeatmapCell(d(6), CellState.future),
    ],
  ]);
}

void main() {
  testWidgets('interactive: tapping an in-range cell calls onToggle with its date',
      (tester) async {
    DateTime? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HeatmapGrid(
          data: _oneWeek(),
          color: Colors.teal,
          interactive: true,
          onToggle: (date) => tapped = date,
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('heatmap-cell-2026-06-09'))); // notCompleted
    expect(tapped, DateTime(2026, 6, 9));
  });

  testWidgets('interactive: future cells do not fire onToggle',
      (tester) async {
    DateTime? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HeatmapGrid(
          data: _oneWeek(),
          color: Colors.teal,
          interactive: true,
          onToggle: (date) => tapped = date,
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('heatmap-cell-2026-06-14'))); // future
    expect(tapped, isNull);
  });

  testWidgets('non-interactive: tapping an in-range cell does nothing', (tester) async {
    DateTime? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HeatmapGrid(
          data: _oneWeek(),
          color: Colors.teal,
          onToggle: (date) => tapped = date, // ignored because interactive defaults false
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('heatmap-cell-2026-06-09')));
    expect(tapped, isNull);
  });

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

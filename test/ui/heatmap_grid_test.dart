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
      HeatmapCell(d(2), CellState.beforeCreation),
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

  testWidgets('interactive: future and beforeCreation cells do not fire onToggle',
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
    await tester.tap(find.byKey(const Key('heatmap-cell-2026-06-10'))); // beforeCreation
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
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/dates.dart';
import '../../domain/heatmap.dart';

/// Renders a [HeatmapData] as columns of weeks (each 7 cells, Monday..Sunday).
/// Read-only — purely the activity picture. Optionally shows month labels.
class HeatmapGrid extends StatelessWidget {
  const HeatmapGrid({
    super.key,
    required this.data,
    required this.color,
    this.cellSize = 14,
    this.cellGap = 3,
    this.showMonthLabels = false,
  });

  final HeatmapData data;
  final Color color;
  final double cellSize;
  final double cellGap;
  final bool showMonthLabels;

  Color _cellColor(CellState state) {
    switch (state) {
      case CellState.completed:
        return color;
      case CellState.notCompleted:
        return color.withValues(alpha: 0.15);
      case CellState.future:
        return Colors.transparent;
    }
  }

  List<String?> _monthLabels(String localeName) {
    final fmt = DateFormat.MMM(localeName);
    final labels = <String?>[];
    int? lastMonth;
    for (final week in data.weeks) {
      final m = week.first.date.month;
      if (m != lastMonth) {
        labels.add(fmt.format(DateTime(2000, m)));
        lastMonth = m;
      } else {
        labels.add(null);
      }
    }
    return labels;
  }

  Widget _labelsRow(String localeName) {
    final labels = _monthLabels(localeName);
    final labelHeight = cellSize * 0.75 * 1.4;
    return Padding(
      padding: EdgeInsets.only(bottom: cellGap),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final label in labels)
            SizedBox(
              width: cellSize + cellGap,
              height: labelHeight,
              child: label == null
                  ? null
                  : OverflowBox(
                      maxWidth: double.infinity,
                      maxHeight: labelHeight,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: TextStyle(fontSize: cellSize * 0.75),
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _grid() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final week in data.weeks)
          Padding(
            padding: EdgeInsets.only(right: cellGap),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final cell in week)
                  Padding(
                    padding: EdgeInsets.only(bottom: cellGap),
                    child: Container(
                      key: ValueKey('heatmap-cell-${formatIsoDate(cell.date)}'),
                      width: cellSize,
                      height: cellSize,
                      decoration: BoxDecoration(
                        color: _cellColor(cell.state),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!showMonthLabels) return _grid();
    // Full locale tag; "en_US" is intl's built-in default and other supported
    // locales are loaded by GlobalMaterialLocalizations.delegate.
    final localeName = Localizations.localeOf(context).toString();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_labelsRow(localeName), _grid()],
    );
  }
}

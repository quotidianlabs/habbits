import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/dates.dart';
import '../../domain/heatmap.dart';
import '../core/habit_colors.dart';

/// Month abbreviations for each week-column, placed where a month begins — the
/// column that contains that month's 1st (not the column's Monday, which only
/// coincides when the 1st falls on a Monday). The leftmost column falls back to
/// its first cell's month as a starting reference; columns with no new month are
/// `null`.
List<String?> monthLabels(List<List<HeatmapCell>> weeks, String localeName) {
  final fmt = DateFormat.MMM(localeName);
  String fmtMonth(int month) => fmt.format(DateTime(2000, month));
  final labels = <String?>[];
  for (var i = 0; i < weeks.length; i++) {
    final week = weeks[i];
    final firstOfMonth = week.where((c) => c.date.day == 1);
    if (firstOfMonth.isNotEmpty) {
      labels.add(fmtMonth(firstOfMonth.first.date.month));
    } else if (i == 0) {
      labels.add(fmtMonth(week.first.date.month));
    } else {
      labels.add(null);
    }
  }
  return labels;
}

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

  Color _cellColor(CellState state, ColorScheme scheme) {
    switch (state) {
      case CellState.completed:
        return color;
      case CellState.notCompleted:
        return inactiveCellColor(color, scheme);
      case CellState.future:
        return Colors.transparent;
    }
  }

  Widget _labelsRow(String localeName) {
    final labels = monthLabels(data.weeks, localeName);
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

  Widget _grid(ColorScheme scheme) {
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
                        color: _cellColor(cell.state, scheme),
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
    final scheme = Theme.of(context).colorScheme;
    if (!showMonthLabels) return _grid(scheme);
    // Full locale tag; "en_US" is intl's built-in default and other supported
    // locales are loaded by GlobalMaterialLocalizations.delegate.
    final localeName = Localizations.localeOf(context).toString();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_labelsRow(localeName), _grid(scheme)],
    );
  }
}

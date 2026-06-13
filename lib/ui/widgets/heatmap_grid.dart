import 'package:flutter/material.dart';

import '../../domain/dates.dart';
import '../../domain/heatmap.dart';

/// Renders a [HeatmapData] as columns of weeks (each 7 cells, Monday..Sunday).
/// When [interactive] is true, tapping a completed/notCompleted cell calls
/// [onToggle] with that cell's date; future and before-creation cells never fire.
class HeatmapGrid extends StatelessWidget {
  const HeatmapGrid({
    super.key,
    required this.data,
    required this.color,
    this.interactive = false,
    this.onToggle,
    this.cellSize = 14,
    this.cellGap = 3,
  });

  final HeatmapData data;
  final Color color;
  final bool interactive;
  final void Function(DateTime date)? onToggle;
  final double cellSize;
  final double cellGap;

  bool _editable(CellState s) =>
      s == CellState.completed || s == CellState.notCompleted;

  Color _cellColor(BuildContext context, CellState state) {
    switch (state) {
      case CellState.completed:
        return color;
      case CellState.notCompleted:
        return color.withValues(alpha: 0.15);
      case CellState.future:
      case CellState.beforeCreation:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    child: _Cell(
                      key: ValueKey('heatmap-cell-${formatIsoDate(cell.date)}'),
                      size: cellSize,
                      color: _cellColor(context, cell.state),
                      onTap: interactive && _editable(cell.state) && onToggle != null
                          ? () => onToggle!(cell.date)
                          : null,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({super.key, required this.size, required this.color, this.onTap});
  final double size;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

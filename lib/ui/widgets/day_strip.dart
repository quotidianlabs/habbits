import 'package:flutter/material.dart';

import '../../domain/dates.dart';
import '../../domain/recent_days.dart';
import '../core/habit_colors.dart';

/// A read-only one-row strip of the last [count] days (oldest -> newest).
class DayStrip extends StatelessWidget {
  const DayStrip({
    super.key,
    required this.completed,
    required this.today,
    required this.color,
    this.count = 14,
    this.cellSize = 12,
    this.cellGap = 3,
  });

  final Set<DateTime> completed;
  final DateTime today;
  final Color color;
  final int count;
  final double cellSize;
  final double cellGap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = recentDays(completed, today, count);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final day in days)
          Padding(
            padding: EdgeInsets.only(right: cellGap),
            child: Container(
              key: ValueKey('daystrip-${formatIsoDate(day.date)}'),
              width: cellSize,
              height: cellSize,
              decoration: BoxDecoration(
                color: day.completed ? color : inactiveCellColor(color, scheme),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
      ],
    );
  }
}

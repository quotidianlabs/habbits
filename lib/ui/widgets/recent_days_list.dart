import 'package:flutter/material.dart';

import '../../domain/calendar_labels.dart';
import '../../domain/dates.dart';
import '../../domain/recent_days.dart';

/// A newest-first list of the last [count] days. Tapping a row (or its checkbox)
/// calls [onToggle] with that day's date.
class RecentDaysList extends StatelessWidget {
  const RecentDaysList({
    super.key,
    required this.completed,
    required this.today,
    required this.onToggle,
    this.count = 30,
  });

  final Set<DateTime> completed;
  final DateTime today;
  final void Function(DateTime date) onToggle;
  final int count;

  String _label(DateTime date) {
    final base = '${weekdayAbbr3(date.weekday)}, ${monthAbbr3(date.month)} ${date.day}';
    return date == dateOnly(today) ? 'Today · $base' : base;
  }

  @override
  Widget build(BuildContext context) {
    final days = recentDays(completed, today, count).reversed.toList(); // newest first
    return Column(
      children: [
        for (final day in days)
          ListTile(
            key: ValueKey('daylist-${formatIsoDate(day.date)}'),
            dense: true,
            title: Text(_label(day.date)),
            trailing: Checkbox(
              value: day.completed,
              onChanged: (_) => onToggle(day.date),
            ),
            onTap: () => onToggle(day.date),
          ),
      ],
    );
  }
}

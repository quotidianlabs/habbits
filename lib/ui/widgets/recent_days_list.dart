import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
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

  String _label(BuildContext context, DateTime date) {
    // Full locale tag (e.g. "en_US"/"ru"); intl date symbols for it are loaded
    // by GlobalMaterialLocalizations.delegate, and "en_US" is intl's built-in
    // default, so DateFormat needs no explicit initializeDateFormatting here.
    final localeName = Localizations.localeOf(context).toString();
    final base = DateFormat.MMMEd(localeName).format(date);
    return date == dateOnly(today)
        ? AppLocalizations.of(context).todayPrefix(base)
        : base;
  }

  @override
  Widget build(BuildContext context) {
    final days = recentDays(
      completed,
      today,
      count,
    ).reversed.toList(); // newest first
    return Column(
      children: [
        for (final day in days)
          ListTile(
            key: ValueKey('daylist-${formatIsoDate(day.date)}'),
            dense: true,
            title: Text(_label(context, day.date)),
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

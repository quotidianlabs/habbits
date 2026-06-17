import 'dates.dart';

/// Completion percentage over a rolling window anchored at the first checked
/// day.
///
/// `completed days ÷ min(30, days from first check to lastDay)`, excluding
/// today when it is not yet checked. The window starts at the earliest checked
/// day — not the habit's creation date — so retroactively backfilled checks
/// (including ones before creation) count, and a long-idle habit is measured
/// from when it was actually started. Returns `null` ("—") when nothing is
/// checked yet. All inputs are normalized to date-only.
int? completionPercent(Set<DateTime> completed, DateTime today) {
  final days = completed.map(dateOnly).toSet();
  if (days.isEmpty) return null;

  final t = dateOnly(today);
  // Today is excluded from the window until it is checked.
  final lastDay = days.contains(t) ? t : previousDay(t);

  final firstDay = days.reduce((a, b) => a.isBefore(b) ? a : b);
  final spanDays = daysBetween(firstDay, lastDay) + 1;
  if (spanDays <= 0) return null;

  final windowDays = spanDays < 30 ? spanDays : 30;
  final windowStart = DateTime(
    lastDay.year,
    lastDay.month,
    lastDay.day - (windowDays - 1),
  );

  var count = 0;
  for (final d in days) {
    if (!d.isBefore(windowStart) && !d.isAfter(lastDay)) count++;
  }
  return ((count / windowDays) * 100).round();
}

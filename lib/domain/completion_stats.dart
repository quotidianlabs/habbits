import 'dates.dart';

/// 30-day completion percentage per the foundation spec §3.
///
/// `completed days ÷ min(30, days since creation)`, excluding today when it is
/// not yet checked. Returns `null` when there is no eligible window yet (e.g.
/// the habit was created today and today is not checked) — the UI renders that
/// as "—". All inputs are normalized to date-only.
int? completionPercent(Set<DateTime> completed, DateTime createdAt, DateTime today) {
  final days = completed.map(dateOnly).toSet();
  final created = dateOnly(createdAt);
  final t = dateOnly(today);

  // Today is excluded from the window until it is checked.
  final lastDay = days.contains(t) ? t : previousDay(t);

  final spanDays = daysBetween(created, lastDay) + 1;
  if (spanDays <= 0) return null;

  final windowDays = spanDays < 30 ? spanDays : 30;
  final windowStart =
      DateTime(lastDay.year, lastDay.month, lastDay.day - (windowDays - 1));

  var count = 0;
  for (final d in days) {
    if (!d.isBefore(windowStart) && !d.isAfter(lastDay)) count++;
  }
  return ((count / windowDays) * 100).round();
}

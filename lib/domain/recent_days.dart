import 'dates.dart';

/// One day in a recent-days window.
class RecentDay {
  const RecentDay(this.date, this.completed);
  final DateTime date;
  final bool completed;
}

/// The last [count] days ending today (inclusive), ordered oldest -> newest.
/// `completed` is whether that date is in [completed]. Never includes future
/// days. All inputs are normalized to date-only; DST-safe via date construction.
List<RecentDay> recentDays(Set<DateTime> completed, DateTime today, int count) {
  final days = completed.map(dateOnly).toSet();
  final t = dateOnly(today);
  final result = <RecentDay>[];
  for (var i = count - 1; i >= 0; i--) {
    final date = DateTime(t.year, t.month, t.day - i);
    result.add(RecentDay(date, days.contains(date)));
  }
  return result;
}

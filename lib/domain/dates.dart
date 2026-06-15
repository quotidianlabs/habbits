/// Pure calendar-date helpers. No Flutter, no Drift imports.
library;

/// Strips the time-of-day, returning a date at local midnight.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The calendar day before [d]. Uses date construction (not Duration) so it is
/// correct across month, year, and DST boundaries.
DateTime previousDay(DateTime d) => DateTime(d.year, d.month, d.day - 1);

/// Formats a date as `YYYY-MM-DD` for storage.
String formatIsoDate(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-$m-$day';
}

/// Parses a `YYYY-MM-DD` string into a date-only [DateTime].
DateTime parseIsoDate(String s) {
  final parts = s.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

/// Number of whole calendar days from [from] to [to] (date-only). Negative if
/// [to] precedes [from]. Divides hours by 24 and rounds so a single DST
/// transition inside the span does not shift the count.
int daysBetween(DateTime from, DateTime to) {
  final f = DateTime(from.year, from.month, from.day);
  final t = DateTime(to.year, to.month, to.day);
  return (t.difference(f).inHours / 24).round();
}

/// The Monday of the week containing [d] (weeks start Monday). DST-safe via
/// calendar-date construction.
DateTime mondayOf(DateTime d) {
  final date = DateTime(d.year, d.month, d.day);
  return DateTime(date.year, date.month, date.day - (date.weekday - 1));
}

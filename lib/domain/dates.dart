/// Pure calendar-date helpers. No Flutter, no Drift imports.

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
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

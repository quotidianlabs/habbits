import 'dates.dart';

/// Current consecutive-day streak per spec §3.
///
/// The streak ends at today if today is completed; otherwise at yesterday (the
/// run is still alive until the day actually lapses). A gap resets it to 0.
/// [completed] may contain times; they are normalized to date-only.
int currentStreak(Set<DateTime> completed, DateTime today) {
  final days = completed.map(dateOnly).toSet();
  final t = dateOnly(today);

  DateTime anchor;
  if (days.contains(t)) {
    anchor = t;
  } else if (days.contains(previousDay(t))) {
    anchor = previousDay(t);
  } else {
    return 0;
  }

  var streak = 0;
  var cursor = anchor;
  while (days.contains(cursor)) {
    streak++;
    cursor = previousDay(cursor);
  }
  return streak;
}

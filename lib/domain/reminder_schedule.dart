/// A habit that has a reminder enabled.
class ReminderHabit {
  const ReminderHabit({
    required this.id,
    required this.name,
    required this.time,
    required this.doneToday,
  });
  final int id;
  final String name;
  final String time; // 'HH:mm'
  final bool doneToday;
}

/// One notification to schedule.
class ScheduledReminder {
  const ScheduledReminder({
    required this.habitId,
    required this.habitName,
    required this.when,
  });
  final int habitId;
  final String habitName;
  final DateTime when; // local wall-clock instant
}

/// Builds the reminder schedule: for each enabled habit, one notification per
/// upcoming day it isn't done, within a rolling buffer sized to respect iOS's
/// pending-notification cap. Today is included only if the habit isn't done and
/// its time is still in the future relative to [now].
List<ScheduledReminder> computeReminderSchedule(
  List<ReminderHabit> enabled,
  DateTime now, {
  int maxBuffer = 14,
  int iosBudget = 64,
}) {
  if (enabled.isEmpty) return const [];
  final days = (iosBudget ~/ enabled.length).clamp(1, maxBuffer);
  final result = <ScheduledReminder>[];
  for (final h in enabled) {
    final parts = h.time.split(':');
    final hh = int.parse(parts[0]);
    final mm = int.parse(parts[1]);
    for (var d = 0; d < days; d++) {
      final when = DateTime(now.year, now.month, now.day + d, hh, mm);
      if (d == 0) {
        if (h.doneToday) continue; // already done today
        if (!when.isAfter(now)) continue; // time already passed today
      }
      result.add(
        ScheduledReminder(habitId: h.id, habitName: h.name, when: when),
      );
    }
  }
  return result;
}

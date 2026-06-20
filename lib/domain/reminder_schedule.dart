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

/// iOS keeps at most this many pending local notifications; anything scheduled
/// beyond it is silently dropped. The reminder schedule is hard-capped here.
const int kIosNotificationBudget = 64;

/// Builds the reminder schedule: for each enabled habit, one notification per
/// upcoming day it isn't done, across a [maxBuffer]-day window. Today is included
/// only if the habit isn't done and its time is still in the future relative to
/// [now]. The full candidate set is then capped at [iosBudget] by keeping the
/// soonest fire times, so the most imminent reminders across all habits win the
/// scarce slots and the OS never silently drops the tail. Starved habits (more
/// than [iosBudget] reminder-enabled) roll into the window on the next resync.
List<ScheduledReminder> computeReminderSchedule(
  List<ReminderHabit> enabled,
  DateTime now, {
  int maxBuffer = 14,
  int iosBudget = kIosNotificationBudget,
}) {
  if (enabled.isEmpty) return const [];
  final all = <ScheduledReminder>[];
  for (final h in enabled) {
    final parts = h.time.split(':');
    final hh = int.parse(parts[0]);
    final mm = int.parse(parts[1]);
    for (var d = 0; d < maxBuffer; d++) {
      final when = DateTime(now.year, now.month, now.day + d, hh, mm);
      if (d == 0) {
        if (h.doneToday) continue; // already done today
        if (!when.isAfter(now)) continue; // time already passed today
      }
      all.add(ScheduledReminder(habitId: h.id, habitName: h.name, when: when));
    }
  }
  all.sort((a, b) => a.when.compareTo(b.when));
  return all.length <= iosBudget ? all : all.sublist(0, iosBudget);
}

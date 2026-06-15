import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dates.dart';
import '../../domain/heatmap.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/habit_dialogs.dart';
import '../widgets/heatmap_grid.dart';
import '../widgets/recent_days_list.dart';
import 'habit_detail_view_model.dart';

class HabitDetailScreen extends ConsumerWidget {
  const HabitDetailScreen({super.key, required this.habitId});
  final int habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(habitDetailViewModelProvider(habitId));

    if (summary == null) {
      return const Scaffold(
        key: Key('habit-detail-screen'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final l10n = AppLocalizations.of(context);
    final today = dateOnly(DateTime.now());
    final data = buildHeatmap(completed: summary.dates, today: today, weeks: 6);
    final percent = summary.completionPercent;

    return Scaffold(
      key: const Key('habit-detail-screen'),
      appBar: AppBar(
        title: Text(summary.habit.name),
        actions: [
          IconButton(
            key: const Key('detail-rename'),
            icon: const Icon(Icons.edit),
            tooltip: l10n.rename,
            onPressed: () async {
              final name = await showHabitNameDialog(
                context,
                initial: summary.habit.name,
                isRename: true,
              );
              if (name != null) {
                await ref
                    .read(habitDetailViewModelProvider(habitId).notifier)
                    .editHabit(name, summary.habit.color);
              }
            },
          ),
          IconButton(
            key: const Key('detail-delete'),
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.delete,
            onPressed: () async {
              final ok = await confirmDeleteHabit(context, summary.habit.name);
              if (!ok) return;
              await ref
                  .read(habitDetailViewModelProvider(habitId).notifier)
                  .delete();
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.streakLabel(summary.streak),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.thirtyDayLabel(percent == null ? '—' : '$percent%'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ListTile(
            key: const Key('reminder-row'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_outlined),
            title: Text(l10n.reminderTitle),
            subtitle: Text(_reminderLabel(context, summary.habit.reminderTime)),
            trailing: Switch(
              key: const Key('reminder-switch'),
              value: summary.habit.reminderTime != null,
              onChanged: (on) => _onReminderToggle(
                context,
                ref,
                habitId,
                on,
                summary.habit.reminderTime,
              ),
            ),
            onTap: summary.habit.reminderTime == null
                ? null
                : () => _pickReminderTime(
                    context,
                    ref,
                    habitId,
                    summary.habit.reminderTime!,
                  ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: HeatmapGrid(
              data: data,
              color: Color(summary.habit.color),
              cellSize: 18,
              showMonthLabels: true,
            ),
          ),
          const SizedBox(height: 16),
          RecentDaysList(
            completed: summary.dates,
            today: today,
            onToggle: (date) => ref
                .read(habitDetailViewModelProvider(habitId).notifier)
                .toggle(date),
          ),
        ],
      ),
    );
  }
}

String _reminderLabel(BuildContext context, String? hhmm) {
  if (hhmm == null) return AppLocalizations.of(context).reminderOff;
  return _toTimeOfDay(hhmm).format(context);
}

TimeOfDay _toTimeOfDay(String hhmm) {
  final parts = hhmm.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

String _toHhmm(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

Future<void> _onReminderToggle(
  BuildContext context,
  WidgetRef ref,
  int habitId,
  bool on,
  String? current,
) async {
  final notifier = ref.read(habitDetailViewModelProvider(habitId).notifier);
  if (!on) {
    await notifier.setReminder(null);
    return;
  }
  final picked = await showTimePicker(
    context: context,
    initialTime: const TimeOfDay(hour: 9, minute: 0),
  );
  if (picked != null) {
    await notifier.setReminder(_toHhmm(picked));
  }
}

Future<void> _pickReminderTime(
  BuildContext context,
  WidgetRef ref,
  int habitId,
  String current,
) async {
  final picked = await showTimePicker(
    context: context,
    initialTime: _toTimeOfDay(current),
  );
  if (picked != null && context.mounted) {
    await ref
        .read(habitDetailViewModelProvider(habitId).notifier)
        .setReminder(_toHhmm(picked));
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dates.dart';
import '../../domain/heatmap.dart';
import '../../state/habit_providers.dart';
import '../widgets/habit_dialogs.dart';
import '../widgets/heatmap_grid.dart';
import '../widgets/recent_days_list.dart';

class HabitDetailScreen extends ConsumerWidget {
  const HabitDetailScreen({super.key, required this.habitId});
  final int habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(habitDetailProvider(habitId));

    if (summary == null) {
      return const Scaffold(
        key: Key('habit-detail-screen'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final dao = ref.read(habitDaoProvider);
    final today = dateOnly(DateTime.now());
    final data = buildHeatmap(
      completed: summary.dates,
      today: today,
      weeks: 6,
    );
    final percent = summary.completionPercent;

    return Scaffold(
      key: const Key('habit-detail-screen'),
      appBar: AppBar(
        title: Text(summary.habit.name),
        actions: [
          IconButton(
            key: const Key('detail-rename'),
            icon: const Icon(Icons.edit),
            tooltip: 'Rename',
            onPressed: () => showHabitNameDialog(
              context,
              ref,
              habitId: habitId,
              initial: summary.habit.name,
            ),
          ),
          IconButton(
            key: const Key('detail-delete'),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: () async {
              final deleted = await confirmDeleteHabit(
                  context, ref, habitId, summary.habit.name);
              if (deleted && context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Streak: ${summary.streak}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('30-day: ${percent == null ? '—' : '$percent%'}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
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
            onToggle: (date) => dao.toggleCompletion(habitId, date),
          ),
        ],
      ),
    );
  }
}

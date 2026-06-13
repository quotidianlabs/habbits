import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dates.dart';
import '../../domain/heatmap.dart';
import '../../state/habit_providers.dart';
import '../habit_detail/habit_detail_screen.dart';
import '../widgets/habit_dialogs.dart';
import '../widgets/heatmap_grid.dart';

class HabitListScreen extends ConsumerWidget {
  const HabitListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(habitSummariesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Habbits')),
      floatingActionButton: FloatingActionButton(
        key: const Key('add-habit-fab'),
        onPressed: () => showHabitNameDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: summaries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No habits yet. Tap + to add one.'));
          }
          return ListView(
            children: [for (final item in items) _HabitCard(item: item)],
          );
        },
      ),
    );
  }
}

class _HabitCard extends ConsumerWidget {
  const _HabitCard({required this.item});
  final HabitSummary item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dao = ref.read(habitDaoProvider);
    final today = dateOnly(DateTime.now());
    final percent = item.completionPercent;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HabitDetailScreen(habitId: item.habit.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.habit.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text('Streak: ${item.streak}'),
                  Checkbox(
                    key: ValueKey('checkoff-toggle-${item.habit.id}'),
                    value: item.doneToday,
                    onChanged: (_) => dao.toggleCompletion(item.habit.id, today),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  const cellSize = 11.0;
                  const cellGap = 2.0;
                  final weeks =
                      (constraints.maxWidth / (cellSize + cellGap)).floor().clamp(1, 26);
                  final data = buildHeatmap(
                    completed: item.dates,
                    createdAt: item.habit.createdAt,
                    today: today,
                    maxWeeks: weeks,
                  );
                  return HeatmapGrid(
                    data: data,
                    color: Color(item.habit.color),
                    cellSize: cellSize,
                    cellGap: cellGap,
                  );
                },
              ),
              const SizedBox(height: 8),
              Text('30-day: ${percent == null ? '—' : '$percent%'}'),
            ],
          ),
        ),
      ),
    );
  }
}

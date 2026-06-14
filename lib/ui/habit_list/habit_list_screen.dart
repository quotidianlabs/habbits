import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dates.dart';
import '../../domain/reorder.dart';
import '../../state/habit_providers.dart';
import '../habit_detail/habit_detail_screen.dart';
import '../settings/settings_screen.dart';
import '../widgets/day_strip.dart';
import '../widgets/habit_dialogs.dart';

class HabitListScreen extends ConsumerWidget {
  const HabitListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(habitSummariesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habbits'),
        actions: [
          IconButton(
            key: const Key('open-settings'),
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
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
          final dao = ref.read(habitDaoProvider);
          return ReorderableListView(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.symmetric(vertical: 6),
            onReorderItem: (oldIndex, newIndex) {
              final ids = [for (final it in items) it.habit.id];
              dao.reorderHabits(reorderedIds(ids, oldIndex, newIndex));
            },
            children: [
              for (var i = 0; i < items.length; i++)
                _HabitCard(
                  key: ValueKey('habit-${items[i].habit.id}'),
                  item: items[i],
                  index: i,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HabitCard extends ConsumerWidget {
  const _HabitCard({super.key, required this.item, required this.index});
  final HabitSummary item;
  final int index;

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
                  Checkbox(
                    key: ValueKey('checkoff-toggle-${item.habit.id}'),
                    value: item.doneToday,
                    onChanged: (_) => dao.toggleCompletion(item.habit.id, today),
                  ),
                  Expanded(
                    child: Text(
                      item.habit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text('Streak: ${item.streak}'),
                  const SizedBox(width: 12),
                  Text(percent == null ? '—' : '$percent%'),
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.drag_handle,
                        key: ValueKey('drag-handle-${item.habit.id}'),
                        color: Theme.of(context).disabledColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              DayStrip(
                completed: item.dates,
                today: today,
                color: Color(item.habit.color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

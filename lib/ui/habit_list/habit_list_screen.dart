import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dates.dart';
import '../../l10n/app_localizations.dart';
import '../../domain/reorder.dart';
import '../../domain/models/habit_summary.dart';
import '../habit_detail/habit_detail_screen.dart';
import '../settings/settings_screen.dart';
import '../widgets/day_strip.dart';
import '../widgets/habit_dialogs.dart';
import 'habit_list_view_model.dart';

class HabitListScreen extends ConsumerWidget {
  const HabitListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(habitListViewModelProvider);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habbits'),
        actions: [
          IconButton(
            key: const Key('open-settings'),
            icon: const Icon(Icons.settings),
            tooltip: l10n.settings,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add-habit-fab'),
        onPressed: () async {
          final name = await showHabitNameDialog(context);
          if (name != null) {
            await ref.read(habitListViewModelProvider.notifier).createHabit(name);
          }
        },
        child: const Icon(Icons.add),
      ),
      body: summaries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.homeError(e.toString()))),
        data: (items) {
          if (items.isEmpty) {
            return Center(child: Text(l10n.noHabits));
          }
          return ReorderableListView(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.symmetric(vertical: 6),
            onReorderItem: (oldIndex, newIndex) {
              final ids = [for (final it in items) it.habit.id];
              ref.read(habitListViewModelProvider.notifier).reorder(reorderedIds(ids, oldIndex, newIndex));
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
    final l10n = AppLocalizations.of(context);
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
                    onChanged: (_) => ref.read(habitListViewModelProvider.notifier).toggleToday(item.habit.id),
                  ),
                  Expanded(
                    child: Text(
                      item.habit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(l10n.streakLabel(item.streak)),
                  const SizedBox(width: 12),
                  Text(percent == null ? '—' : '$percent%'),
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.drag_handle,
                        key: ValueKey('drag-handle-${item.habit.id}'),
                        semanticLabel: l10n.dragToReorder(item.habit.name),
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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

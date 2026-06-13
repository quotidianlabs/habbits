import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dates.dart';
import '../../state/habit_providers.dart';
import '../widgets/habit_dialogs.dart';

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
            children: [for (final item in items) _HabitTile(item: item)],
          );
        },
      ),
    );
  }
}

class _HabitTile extends ConsumerWidget {
  const _HabitTile({required this.item});
  final HabitSummary item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dao = ref.read(habitDaoProvider);
    return ListTile(
      leading: Checkbox(
        key: ValueKey('checkoff-toggle-${item.habit.id}'),
        value: item.doneToday,
        onChanged: (_) =>
            dao.toggleCompletion(item.habit.id, dateOnly(DateTime.now())),
      ),
      title: Text(item.habit.name),
      subtitle: Text('Streak: ${item.streak}'),
      trailing: PopupMenuButton<String>(
        key: ValueKey('habit-menu-${item.habit.id}'),
        onSelected: (value) {
          if (value == 'rename') {
            showHabitNameDialog(context, ref,
                habitId: item.habit.id, initial: item.habit.name);
          } else if (value == 'delete') {
            confirmDeleteHabit(context, ref, item.habit.id, item.habit.name);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'rename', child: Text('Rename')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}

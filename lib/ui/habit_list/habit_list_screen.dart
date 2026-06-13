import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dates.dart';
import '../../state/habit_providers.dart';

class HabitListScreen extends ConsumerWidget {
  const HabitListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(habitSummariesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Habbits')),
      floatingActionButton: FloatingActionButton(
        key: const Key('add-habit-fab'),
        onPressed: () => _showNameDialog(context, ref),
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
        key: const Key('checkoff-toggle'),
        value: item.doneToday,
        onChanged: (_) =>
            dao.toggleCompletion(item.habit.id, dateOnly(DateTime.now())),
      ),
      title: Text(item.habit.name),
      subtitle: Text('Streak: ${item.streak}'),
      trailing: PopupMenuButton<String>(
        key: const Key('habit-menu'),
        onSelected: (value) {
          if (value == 'rename') {
            _showNameDialog(
              context,
              ref,
              habitId: item.habit.id,
              initial: item.habit.name,
            );
          } else if (value == 'delete') {
            _confirmDelete(context, ref, item.habit.id, item.habit.name);
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

Future<void> _showNameDialog(
  BuildContext context,
  WidgetRef ref, {
  int? habitId,
  String? initial,
}) async {
  final dao = ref.read(habitDaoProvider);
  final controller = TextEditingController(text: initial ?? '');
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(habitId == null ? 'New habit' : 'Rename habit'),
      content: TextField(
        key: const Key('habit-name-field'),
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('habit-name-confirm'),
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (name == null || name.isEmpty) return;
  if (habitId == null) {
    await dao.createHabit(name: name, color: Colors.teal.toARGB32());
  } else {
    await dao.renameHabit(habitId, name);
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  int habitId,
  String name,
) async {
  final dao = ref.read(habitDaoProvider);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete "$name"?'),
      content: const Text(
        'This permanently deletes the habit and all its check-off history. '
        'This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('confirm-delete'),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await dao.deleteHabit(habitId);
  }
}

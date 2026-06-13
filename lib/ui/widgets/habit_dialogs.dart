import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/habit_providers.dart';

/// Shows the create/rename name dialog. With [habitId] null it creates a new
/// habit; otherwise it renames the given habit.
Future<void> showHabitNameDialog(
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

/// Shows the permanent-delete confirmation. Returns true if the habit was
/// deleted, false if the user cancelled.
Future<bool> confirmDeleteHabit(
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
    return true;
  }
  return false;
}

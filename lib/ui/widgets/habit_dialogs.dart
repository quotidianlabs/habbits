import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/habit_repository.dart';
import '../../l10n/app_localizations.dart';
import '../habit_list/habit_list_view_model.dart';

/// Shows the create/rename name dialog. With [habitId] null it creates a new
/// habit; otherwise it renames the given habit.
Future<void> showHabitNameDialog(
  BuildContext context,
  WidgetRef ref, {
  int? habitId,
  String? initial,
}) async {
  final controller = TextEditingController(text: initial ?? '');
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx);
      return AlertDialog(
        title: Text(habitId == null ? l10n.newHabit : l10n.renameHabit),
        content: TextField(
          key: const Key('habit-name-field'),
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.nameLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const Key('habit-name-confirm'),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      );
    },
  );

  if (name == null || name.isEmpty) return;
  if (habitId == null) {
    await ref.read(habitListViewModelProvider.notifier).createHabit(name, color: Colors.teal.toARGB32());
  } else {
    await ref.read(habitRepositoryProvider).renameHabit(habitId, name);
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
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx);
      return AlertDialog(
        title: Text(l10n.deleteHabitTitle(name)),
        content: Text(l10n.deleteHabitBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const Key('confirm-delete'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      );
    },
  );
  if (confirmed == true) {
    await ref.read(habitRepositoryProvider).deleteHabit(habitId);
    return true;
  }
  return false;
}

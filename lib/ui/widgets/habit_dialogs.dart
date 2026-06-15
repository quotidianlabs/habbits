import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Shows the create/rename name dialog. Returns the trimmed name, or null if the
/// user cancelled or entered nothing. [initial] pre-fills the field (rename).
/// [isRename] only switches the title; the caller performs the create/rename.
Future<String?> showHabitNameDialog(
  BuildContext context, {
  String? initial,
  bool isRename = false,
}) async {
  final controller = TextEditingController(text: initial ?? '');
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx);
      return AlertDialog(
        title: Text(isRename ? l10n.renameHabit : l10n.newHabit),
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
  if (name == null || name.isEmpty) return null;
  return name;
}

/// Shows the permanent-delete confirmation. Returns true if the user confirmed.
Future<bool> confirmDeleteHabit(BuildContext context, String name) async {
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
  return confirmed ?? false;
}

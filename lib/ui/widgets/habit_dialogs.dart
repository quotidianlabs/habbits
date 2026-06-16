import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../core/habit_colors.dart';

/// The result of the create/edit dialog: the trimmed name + chosen color.
class HabitFormResult {
  const HabitFormResult(this.name, this.color);
  final String name;
  final int color;
}

/// Shows the create/edit dialog. Returns the [HabitFormResult], or null if the
/// user cancelled or entered nothing. [initialName]/[initialColor] pre-fill the
/// fields (edit). [isRename] only switches the title.
Future<HabitFormResult?> showHabitNameDialog(
  BuildContext context, {
  String? initialName,
  int? initialColor,
  bool isRename = false,
}) {
  return showDialog<HabitFormResult>(
    context: context,
    builder: (ctx) => _HabitFormDialog(
      initialName: initialName ?? '',
      initialColor: initialColor ?? kDefaultHabitColor,
      isRename: isRename,
    ),
  );
}

class _HabitFormDialog extends StatefulWidget {
  const _HabitFormDialog({
    required this.initialName,
    required this.initialColor,
    required this.isRename,
  });
  final String initialName;
  final int initialColor;
  final bool isRename;

  @override
  State<_HabitFormDialog> createState() => _HabitFormDialogState();
}

class _HabitFormDialogState extends State<_HabitFormDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );
  late int _color = widget.initialColor;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(context, HabitFormResult(name, _color));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.isRename ? l10n.renameHabit : l10n.newHabit),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('habit-name-field'),
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.nameLabel),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          Text(l10n.color),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in kHabitPalette)
                GestureDetector(
                  key: Key('habit-color-${value.toRadixString(16)}'),
                  onTap: () => setState(() => _color = value),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(value),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.onSurface,
                        width: value == _color ? 3 : 0,
                      ),
                    ),
                    child: value == _color
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          key: const Key('habit-name-confirm'),
          onPressed: _submit,
          child: Text(l10n.save),
        ),
      ],
    );
  }
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

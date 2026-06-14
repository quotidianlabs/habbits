import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/backup.dart';
import '../../services/backup_service.dart';
import '../../state/habit_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      key: const Key('settings-screen'),
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            key: const Key('export-data'),
            leading: const Icon(Icons.upload_file),
            title: const Text('Export data'),
            subtitle: const Text('Save all habits and history to a JSON file'),
            onTap: () => _export(context, ref),
          ),
          ListTile(
            key: const Key('import-data'),
            leading: const Icon(Icons.download),
            title: const Text('Import data'),
            subtitle: const Text('Replace all data from a JSON backup'),
            onTap: () => _import(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      await exportAndShare(ref.read(habitDaoProvider));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed.')),
        );
      }
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final BackupData? data;
    try {
      data = await pickAndDecode();
    } on BackupFormatException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't read that file.")),
        );
      }
      return;
    }
    if (data == null || !context.mounted) return; // cancelled
    await confirmAndImport(context, ref, data);
  }
}

/// Shows the replace-confirmation for [data]; on confirm, replaces all data.
/// Public so it can be widget-tested without the file picker.
Future<void> confirmAndImport(
  BuildContext context,
  WidgetRef ref,
  BackupData data,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Replace all data?'),
      content: Text(
        'This will replace all current habits and history with the file\'s '
        'contents (${data.habits.length} habits). This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('confirm-import'),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Replace'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    try {
      await ref.read(habitDaoProvider).importReplace(data.habits);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Import failed. Your existing data was not changed.'),
          ),
        );
      }
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${data.habits.length} habits')),
      );
    }
  }
}

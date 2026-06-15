import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/backup_data.dart';
import '../../l10n/app_localizations.dart';
import '../core/locale_controller.dart';
import '../core/theme_controller.dart';
import 'settings_view_model.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: const Key('settings-screen'),
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          ListTile(
            key: const Key('export-data'),
            leading: const Icon(Icons.upload_file),
            title: Text(l10n.exportTitle),
            subtitle: Text(l10n.exportSubtitle),
            onTap: () => _export(context, ref),
          ),
          ListTile(
            key: const Key('import-data'),
            leading: const Icon(Icons.download),
            title: Text(l10n.importTitle),
            subtitle: Text(l10n.importSubtitle),
            onTap: () => _import(context, ref),
          ),
          Consumer(
            builder: (context, ref, _) {
              final current = ref.watch(localeControllerProvider);
              return ListTile(
                key: const Key('language-tile'),
                leading: const Icon(Icons.language),
                title: Text(l10n.language),
                subtitle: Text(_localeName(l10n, current)),
                onTap: () => _pickLanguage(context, ref, current),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final current = ref.watch(themeControllerProvider);
              return ListTile(
                key: const Key('theme-tile'),
                leading: const Icon(Icons.brightness_6),
                title: Text(l10n.theme),
                subtitle: Text(_themeName(l10n, current)),
                onTap: () => _pickTheme(context, ref, current),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(settingsViewModelProvider.notifier).export();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.exportFailed)));
      }
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final BackupData? data;
    try {
      data = await ref.read(settingsViewModelProvider.notifier).pickImport();
    } on BackupFormatException catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.invalidBackupFile)));
      }
      return;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldntReadFile)));
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
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.replaceTitle),
      content: Text(l10n.replaceBody(data.habits.length)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          key: const Key('confirm-import'),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.replace),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    try {
      await ref.read(settingsViewModelProvider.notifier).applyImport(data);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.importFailed)));
      }
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.importedHabits(data.habits.length))),
      );
    }
  }
}

String _localeName(AppLocalizations l10n, AppLocale locale) => switch (locale) {
  AppLocale.system => l10n.languageSystem,
  AppLocale.en => 'English',
  AppLocale.ru => 'Русский',
};

Future<void> _pickLanguage(
  BuildContext context,
  WidgetRef ref,
  AppLocale current,
) async {
  final l10n = AppLocalizations.of(context);
  final chosen = await showDialog<AppLocale>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(l10n.language),
      children: [
        for (final option in AppLocale.values)
          ListTile(
            key: Key('lang-option-${option.storage}'),
            title: Text(_localeName(l10n, option)),
            trailing: option == current ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(ctx, option),
          ),
      ],
    ),
  );
  if (chosen != null) {
    await ref.read(localeControllerProvider.notifier).set(chosen);
  }
}

String _themeName(AppLocalizations l10n, AppThemeMode mode) => switch (mode) {
  AppThemeMode.system => l10n.themeSystem,
  AppThemeMode.light => l10n.themeLight,
  AppThemeMode.dark => l10n.themeDark,
};

Future<void> _pickTheme(
  BuildContext context,
  WidgetRef ref,
  AppThemeMode current,
) async {
  final l10n = AppLocalizations.of(context);
  final chosen = await showDialog<AppThemeMode>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(l10n.theme),
      children: [
        for (final option in AppThemeMode.values)
          ListTile(
            key: Key('theme-option-${option.storage}'),
            title: Text(_themeName(l10n, option)),
            trailing: option == current ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(ctx, option),
          ),
      ],
    ),
  );
  if (chosen != null) {
    await ref.read(themeControllerProvider.notifier).set(chosen);
  }
}

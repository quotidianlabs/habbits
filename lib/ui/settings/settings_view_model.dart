import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repositories/backup_repository.dart';
import '../../data/repositories/habit_repository.dart';
import '../../domain/models/backup_data.dart';

part 'settings_view_model.g.dart';

/// Commands for the settings screen's data-management actions. The view keeps
/// ownership of snackbars/dialogs; this exposes the operations they call.
@riverpod
class SettingsViewModel extends _$SettingsViewModel {
  @override
  void build() {}

  Future<void> export(String subject) =>
      ref.read(backupRepositoryProvider).exportAndShare(subject: subject);

  /// Returns the decoded backup, or null if the user cancelled. Throws
  /// [BackupFormatException] on an invalid file (the view maps it to a message).
  Future<BackupData?> pickImport() =>
      ref.read(backupRepositoryProvider).pickAndDecode();

  Future<void> applyImport(BackupData data) =>
      ref.read(habitRepositoryProvider).importReplace(data.habits);
}

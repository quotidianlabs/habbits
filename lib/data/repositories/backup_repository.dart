import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/backup_codec.dart';
import '../../domain/dates.dart';
import '../../domain/models/backup_data.dart';
import 'habit_repository.dart';

part 'backup_repository.g.dart';

/// Orchestrates backup export/import over [HabitRepository] + file/share/picker.
class BackupRepository {
  BackupRepository(this._habits);
  final HabitRepository _habits;

  /// Writes the current data to a temp JSON file and opens the OS share sheet.
  /// [subject] is the localized share-sheet subject, resolved in the UI layer
  /// (this layer has no `BuildContext`).
  Future<void> exportAndShare({required String subject}) async {
    final now = DateTime.now();
    final json = encodeBackup(buildBackup(await _habits.getHabits(), now));
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/habbits-backup-${formatIsoDate(now)}.json');
    await file.writeAsString(json);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: subject),
    );
  }

  /// Lets the user pick a file and decodes it. Returns null if cancelled; throws
  /// [BackupFormatException] if the file is not a valid backup.
  Future<BackupData?> pickAndDecode() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    final path = result?.files.single.path;
    if (path == null) return null;
    return decodeBackup(await File(path).readAsString());
  }
}

@Riverpod(keepAlive: true)
BackupRepository backupRepository(Ref ref) =>
    BackupRepository(ref.watch(habitRepositoryProvider));

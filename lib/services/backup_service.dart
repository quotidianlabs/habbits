import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/habit_dao.dart';
import '../domain/backup.dart';
import '../domain/dates.dart';

/// Builds a [BackupData] snapshot from DAO rows. Pure (no I/O). Completion dates
/// are sorted ascending for a stable file.
BackupData buildBackup(List<HabitWithDates> rows, DateTime now) {
  return BackupData(
    version: 1,
    exportedAt: now,
    habits: [
      for (final r in rows)
        BackupHabit(
          name: r.habit.name,
          color: r.habit.color,
          reminderTime: r.habit.reminderTime,
          sortOrder: r.habit.sortOrder,
          createdAt: r.habit.createdAt,
          completions: (r.dates.toList()..sort()).map(formatIsoDate).toList(),
        ),
    ],
  );
}

/// Writes the current data to a temp JSON file and opens the OS share sheet.
Future<void> exportAndShare(HabitDao dao) async {
  final now = DateTime.now();
  final json = encodeBackup(buildBackup(await dao.getHabitsWithDates(), now));
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/habbits-backup-${formatIsoDate(now)}.json');
  await file.writeAsString(json);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], subject: 'Habbits backup'),
  );
}

/// Lets the user pick a file and decodes it. Returns null if cancelled; throws
/// [BackupFormatException] if the file is not a valid backup.
Future<BackupData?> pickAndDecode() async {
  final result = await FilePicker.platform.pickFiles();
  final path = result?.files.single.path;
  if (path == null) return null;
  return decodeBackup(await File(path).readAsString());
}

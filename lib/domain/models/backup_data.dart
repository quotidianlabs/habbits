/// One habit in a backup, with its completion dates inline.
class BackupHabit {
  const BackupHabit({
    required this.name,
    required this.color,
    required this.reminderTime,
    required this.sortOrder,
    required this.createdAt,
    required this.completions,
  });
  final String name;
  final int color;
  final String? reminderTime;
  final int sortOrder;
  final DateTime createdAt;
  final List<String> completions; // 'YYYY-MM-DD'
}

/// A full backup document.
class BackupData {
  const BackupData({
    required this.version,
    required this.exportedAt,
    required this.habits,
  });
  final int version;
  final DateTime exportedAt;
  final List<BackupHabit> habits;
}

/// Thrown when a file is not a valid Habbits backup. [message] is user-facing.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;
  @override
  String toString() => 'BackupFormatException: $message';
}

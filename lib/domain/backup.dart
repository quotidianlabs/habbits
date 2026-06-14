import 'dart:convert';

const int _currentVersion = 1;

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

/// Serializes [data] to a pretty JSON string.
String encodeBackup(BackupData data) {
  final map = {
    'app': 'habbits',
    'version': data.version,
    'exportedAt': data.exportedAt.toIso8601String(),
    'habits': [
      for (final h in data.habits)
        {
          'name': h.name,
          'color': h.color,
          'reminderTime': h.reminderTime,
          'sortOrder': h.sortOrder,
          'createdAt': h.createdAt.toIso8601String(),
          'completions': h.completions,
        },
    ],
  };
  return const JsonEncoder.withIndent('  ').convert(map);
}

/// Parses and strictly validates a backup string. Throws [BackupFormatException]
/// on anything invalid — never returns a partial result.
BackupData decodeBackup(String source) {
  final Object? root;
  try {
    root = jsonDecode(source);
  } catch (_) {
    throw const BackupFormatException('Not a valid JSON file.');
  }
  if (root is! Map<String, dynamic>) {
    throw const BackupFormatException('Not a valid Habbits backup file.');
  }
  if (root['app'] != 'habbits') {
    throw const BackupFormatException('This is not a Habbits backup file.');
  }
  final version = root['version'];
  if (version is! int || version != _currentVersion) {
    throw BackupFormatException('Unsupported backup version: ${root['version']}.');
  }
  final exportedRaw = root['exportedAt'];
  final exportedAt = exportedRaw is String ? DateTime.tryParse(exportedRaw) : null;
  if (exportedAt == null) {
    throw const BackupFormatException('Missing or invalid exportedAt.');
  }
  final habitsRaw = root['habits'];
  if (habitsRaw is! List) {
    throw const BackupFormatException('Backup is missing its habits list.');
  }
  final habits = [for (final item in habitsRaw) _decodeHabit(item)];
  return BackupData(version: version, exportedAt: exportedAt, habits: habits);
}

BackupHabit _decodeHabit(Object? item) {
  if (item is! Map<String, dynamic>) {
    throw const BackupFormatException('Invalid habit entry.');
  }
  final name = item['name'];
  if (name is! String || name.isEmpty) {
    throw const BackupFormatException('A habit is missing its name.');
  }
  final color = item['color'];
  if (color is! int) {
    throw BackupFormatException('Habit "$name" has an invalid color.');
  }
  final sortOrder = item['sortOrder'];
  if (sortOrder is! int) {
    throw BackupFormatException('Habit "$name" has an invalid sortOrder.');
  }
  final reminder = item['reminderTime'];
  if (reminder != null && reminder is! String) {
    throw BackupFormatException('Habit "$name" has an invalid reminderTime.');
  }
  final createdRaw = item['createdAt'];
  final createdAt = createdRaw is String ? DateTime.tryParse(createdRaw) : null;
  if (createdAt == null) {
    throw BackupFormatException('Habit "$name" has an invalid createdAt.');
  }
  final completionsRaw = item['completions'];
  if (completionsRaw is! List) {
    throw BackupFormatException('Habit "$name" has an invalid completions list.');
  }
  final completions = <String>[];
  for (final c in completionsRaw) {
    if (c is! String || !_isValidIsoDate(c)) {
      throw BackupFormatException('Habit "$name" has an invalid completion date: $c.');
    }
    completions.add(c);
  }
  return BackupHabit(
    name: name,
    color: color,
    reminderTime: reminder as String?,
    sortOrder: sortOrder,
    createdAt: createdAt,
    completions: completions,
  );
}

bool _isValidIsoDate(String s) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return false;
  final parts = s.split('-');
  final y = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  final d = int.parse(parts[2]);
  if (m < 1 || m > 12 || d < 1 || d > 31) return false;
  final dt = DateTime(y, m, d);
  return dt.year == y && dt.month == m && dt.day == d; // rejects e.g. 2026-02-30
}

import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/backup_codec.dart';
import 'package:habbits/domain/models/backup_data.dart';

void main() {
  test('encode -> decode round-trips a backup', () {
    final data = BackupData(
      version: 1,
      exportedAt: DateTime.parse('2026-06-14T09:00:00.000'),
      habits: [
        BackupHabit(
          name: 'Read',
          color: 42,
          reminderTime: null,
          sortOrder: 0,
          createdAt: DateTime.parse('2026-06-01T08:00:00.000'),
          completions: const ['2026-06-01', '2026-06-02'],
        ),
        BackupHabit(
          name: 'Medicine',
          color: 99,
          reminderTime: '08:30',
          sortOrder: 1,
          createdAt: DateTime.parse('2026-05-20T07:00:00.000'),
          completions: const [],
        ),
      ],
    );

    final decoded = decodeBackup(encodeBackup(data));
    expect(decoded.version, 1);
    expect(decoded.habits, hasLength(2));
    final read = decoded.habits.first;
    expect(read.name, 'Read');
    expect(read.color, 42);
    expect(read.reminderTime, isNull);
    expect(read.sortOrder, 0);
    expect(read.createdAt, DateTime.parse('2026-06-01T08:00:00.000'));
    expect(read.completions, ['2026-06-01', '2026-06-02']);
    expect(decoded.habits[1].reminderTime, '08:30');
  });

  group('decodeBackup rejects invalid input', () {
    void expectReject(String src) =>
        expect(() => decodeBackup(src), throwsA(isA<BackupFormatException>()));

    test('non-JSON text', () => expectReject('not json at all'));
    test('a JSON array, not an object', () => expectReject('[]'));
    test(
      'wrong app marker',
      () => expectReject(
        '{"app":"other","version":1,"exportedAt":"2026-06-14T00:00:00.000","habits":[]}',
      ),
    );
    test(
      'unsupported version',
      () => expectReject(
        '{"app":"habbits","version":2,"exportedAt":"2026-06-14T00:00:00.000","habits":[]}',
      ),
    );
    test(
      'missing habits list',
      () => expectReject(
        '{"app":"habbits","version":1,"exportedAt":"2026-06-14T00:00:00.000"}',
      ),
    );
    test(
      'habit missing name',
      () => expectReject(
        '{"app":"habbits","version":1,"exportedAt":"2026-06-14T00:00:00.000","habits":[{"color":1,"sortOrder":0,"createdAt":"2026-06-01T00:00:00.000","completions":[]}]}',
      ),
    );
    test(
      'habit with a malformed completion date',
      () => expectReject(
        '{"app":"habbits","version":1,"exportedAt":"2026-06-14T00:00:00.000","habits":[{"name":"X","color":1,"sortOrder":0,"createdAt":"2026-06-01T00:00:00.000","completions":["2026-13-40"]}]}',
      ),
    );
  });

  test('decodes an empty-habits backup', () {
    final decoded = decodeBackup(
      '{"app":"habbits","version":1,"exportedAt":"2026-06-14T00:00:00.000","habits":[]}',
    );
    expect(decoded.habits, isEmpty);
  });
}

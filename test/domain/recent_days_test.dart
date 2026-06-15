import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/recent_days.dart';

void main() {
  final today = DateTime(2026, 6, 13);

  test('returns count days ending today, ordered oldest -> newest', () {
    final r = recentDays(const {}, today, 3);
    expect(r.length, 3);
    expect(r.first.date, DateTime(2026, 6, 11));
    expect(r.last.date, DateTime(2026, 6, 13));
  });

  test('marks completed days', () {
    final r = recentDays({DateTime(2026, 6, 12)}, today, 3);
    expect(r[0].completed, isFalse); // Jun 11
    expect(r[1].completed, isTrue); // Jun 12
    expect(r[2].completed, isFalse); // Jun 13
  });

  test('normalizes time components in inputs', () {
    final r = recentDays(
      {DateTime(2026, 6, 13, 9)},
      DateTime(2026, 6, 13, 23),
      1,
    );
    expect(r.single.date, DateTime(2026, 6, 13));
    expect(r.single.completed, isTrue);
  });

  test('never includes a future day (ends at today)', () {
    final r = recentDays(const {}, today, 5);
    expect(r.last.date, today);
    expect(r.every((d) => !d.date.isAfter(today)), isTrue);
  });

  test('crosses a month boundary correctly', () {
    final r = recentDays(const {}, DateTime(2026, 3, 1), 3);
    expect(r.first.date, DateTime(2026, 2, 27));
    expect(r.last.date, DateTime(2026, 3, 1));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/dates.dart';

void main() {
  test('dateOnly strips the time component', () {
    expect(dateOnly(DateTime(2026, 6, 13, 14, 30, 59)), DateTime(2026, 6, 13));
  });

  test('previousDay rolls back across a month boundary', () {
    expect(previousDay(DateTime(2026, 3, 1)), DateTime(2026, 2, 28));
  });

  test('previousDay rolls back across a year boundary', () {
    expect(previousDay(DateTime(2026, 1, 1)), DateTime(2025, 12, 31));
  });

  test('previousDay is correct across a DST spring-forward date (US 2026-03-08)', () {
    expect(previousDay(DateTime(2026, 3, 9)), DateTime(2026, 3, 8));
    expect(previousDay(DateTime(2026, 3, 8)), DateTime(2026, 3, 7));
  });

  test('formatIsoDate and parseIsoDate round-trip', () {
    final d = DateTime(2026, 6, 13);
    expect(formatIsoDate(d), '2026-06-13');
    expect(parseIsoDate('2026-06-13'), d);
  });

  test('daysBetween counts whole calendar days, DST-safe', () {
    expect(daysBetween(DateTime(2026, 6, 13), DateTime(2026, 6, 13)), 0);
    expect(daysBetween(DateTime(2026, 6, 13), DateTime(2026, 6, 14)), 1);
    expect(daysBetween(DateTime(2026, 3, 1), DateTime(2026, 3, 31)), 30);
    // Spans the US spring-forward (2026-03-08); must still be 7 calendar days.
    expect(daysBetween(DateTime(2026, 3, 5), DateTime(2026, 3, 12)), 7);
    // Negative when 'to' precedes 'from'.
    expect(daysBetween(DateTime(2026, 6, 14), DateTime(2026, 6, 13)), -1);
  });

  test('mondayOf returns the Monday of the week containing the date', () {
    // 2026-06-13 is a Saturday.
    expect(mondayOf(DateTime(2026, 6, 13)), DateTime(2026, 6, 8));
    // A Monday maps to itself.
    expect(mondayOf(DateTime(2026, 6, 8)), DateTime(2026, 6, 8));
    // A Sunday maps to the Monday 6 days earlier.
    expect(mondayOf(DateTime(2026, 6, 14)), DateTime(2026, 6, 8));
  });
}

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
}

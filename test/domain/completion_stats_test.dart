import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/completion_stats.dart';

void main() {
  final today = DateTime(2026, 6, 13);
  DateTime daysAgo(int n) => DateTime(2026, 6, 13 - n);

  test('created today, nothing checked -> null (no eligible window)', () {
    expect(completionPercent(<DateTime>{}, today, today), isNull);
  });

  test('created today, checked today -> 100', () {
    expect(completionPercent({daysAgo(0)}, today, today), 100);
  });

  test('today unchecked is excluded from the window', () {
    // Created 2 days ago; checked the two prior days but not today.
    // Window ends yesterday, size = 2, completed = 2 -> 100.
    final created = daysAgo(2);
    expect(completionPercent({daysAgo(1), daysAgo(2)}, created, today), 100);
  });

  test('partial window under 30 days', () {
    // Created 4 days ago, checked 3 of the 5 days incl today -> 3/5 = 60.
    final created = daysAgo(4);
    final done = {daysAgo(0), daysAgo(1), daysAgo(3)};
    expect(completionPercent(done, created, today), 60);
  });

  test('window caps at 30 days for old habits', () {
    // Created 100 days ago; completed exactly the 15 most recent days incl today.
    final created = daysAgo(100);
    final done = {for (var i = 0; i < 15; i++) daysAgo(i)};
    expect(completionPercent(done, created, today), 50); // 15 / 30
  });

  test('rounds to nearest integer percent', () {
    // Created 2 days ago, checked today only, window = 3 (today checked) -> 1/3 = 33.
    final created = daysAgo(2);
    expect(completionPercent({daysAgo(0)}, created, today), 33);
  });
}

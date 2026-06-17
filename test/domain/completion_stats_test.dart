import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/completion_stats.dart';

void main() {
  final today = DateTime(2026, 6, 13);
  DateTime daysAgo(int n) => DateTime(2026, 6, 13 - n);

  test('nothing checked -> null (no window yet)', () {
    expect(completionPercent(<DateTime>{}, today), isNull);
  });

  test('checked today only -> 100', () {
    expect(completionPercent({daysAgo(0)}, today), 100);
  });

  test('today unchecked is excluded from the window', () {
    // Checked the two prior days but not today: window ends yesterday,
    // first check 2 days ago, size = 2, completed = 2 -> 100.
    expect(completionPercent({daysAgo(1), daysAgo(2)}, today), 100);
  });

  test('window starts at the first checked day, not earlier', () {
    // First check 3 days ago, 3 of those 4 days incl today -> 3/4 = 75.
    final done = {daysAgo(0), daysAgo(1), daysAgo(3)};
    expect(completionPercent(done, today), 75);
  });

  test('checks before the creation date still count', () {
    // No createdAt floor: 5 consecutive backfilled days incl today,
    // window = first check (4 days ago)..today = 5, all done -> 100.
    final done = {for (var i = 0; i < 5; i++) daysAgo(i)};
    expect(completionPercent(done, today), 100);
  });

  test('window caps at 30 days for long-running habits', () {
    // First check 40 days ago (outside the cap); 15 of the last 30 days done.
    // Denominator capped at 30 -> 15/30 = 50.
    final done = {daysAgo(40), for (var i = 0; i < 15; i++) daysAgo(i)};
    expect(completionPercent(done, today), 50);
  });

  test('rounds to nearest integer percent', () {
    // First check 2 days ago, checked that day and today -> 2/3 = 67.
    expect(completionPercent({daysAgo(2), daysAgo(0)}, today), 67);
  });
}

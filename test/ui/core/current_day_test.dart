import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/dates.dart';
import 'package:habbits/ui/core/current_day.dart';

void main() {
  test('defaults to today and refresh is a no-op on the same day', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final today = dateOnly(DateTime.now());
    expect(container.read(currentDayProvider), today);

    container.read(currentDayProvider.notifier).refresh();
    expect(container.read(currentDayProvider), today); // same day -> unchanged
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/reorder.dart';

void main() {
  test('moves the first item to the end', () {
    expect(reorderedIds([10, 20, 30], 0, 3), [20, 30, 10]);
  });

  test('moves the last item to the front', () {
    expect(reorderedIds([10, 20, 30], 2, 0), [30, 10, 20]);
  });

  test('moves an item down past one neighbour', () {
    // drag index 0 to just after index 1 -> newIndex 2 -> decremented to 1
    expect(reorderedIds([10, 20, 30], 0, 2), [20, 10, 30]);
  });

  test('moves an item up by one', () {
    // upward move: newIndex is NOT decremented (distinct from the down case)
    expect(reorderedIds([10, 20, 30, 40], 2, 1), [10, 30, 20, 40]);
  });

  test('single-item list is unchanged', () {
    expect(reorderedIds([10], 0, 1), [10]);
  });

  test('does not mutate the input list', () {
    final input = [10, 20, 30];
    reorderedIds(input, 0, 2);
    expect(input, [10, 20, 30]);
  });
}

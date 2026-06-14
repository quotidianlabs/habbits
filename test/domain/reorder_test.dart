import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/reorder.dart';

// newIndex follows ReorderableListView's `onReorderItem` convention: it is the
// destination index in the list AFTER the dragged item is removed (no manual
// decrement on downward moves).
void main() {
  test('moves the first item to the end', () {
    expect(reorderedIds([10, 20, 30], 0, 2), [20, 30, 10]);
  });

  test('moves the last item to the front', () {
    expect(reorderedIds([10, 20, 30], 2, 0), [30, 10, 20]);
  });

  test('moves an item down past one neighbour', () {
    // drag index 0 down by one -> onReorderItem reports newIndex 1 (already
    // adjusted); no further decrement.
    expect(reorderedIds([10, 20, 30], 0, 1), [20, 10, 30]);
  });

  test('moves an item up by one', () {
    expect(reorderedIds([10, 20, 30, 40], 2, 1), [10, 30, 20, 40]);
  });

  test('single-item list is unchanged', () {
    expect(reorderedIds([10], 0, 0), [10]);
  });

  test('does not mutate the input list', () {
    final input = [10, 20, 30];
    reorderedIds(input, 0, 1);
    expect(input, [10, 20, 30]);
  });
}

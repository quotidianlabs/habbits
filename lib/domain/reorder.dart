/// Returns a new list with the item at [oldIndex] moved to [newIndex], applying
/// `ReorderableListView`'s index convention: when moving an item downward,
/// [newIndex] is one past the intended slot, so it is decremented. Does not
/// mutate [ids].
List<int> reorderedIds(List<int> ids, int oldIndex, int newIndex) {
  final list = [...ids];
  var target = newIndex;
  if (target > oldIndex) target -= 1;
  final item = list.removeAt(oldIndex);
  list.insert(target, item);
  return list;
}

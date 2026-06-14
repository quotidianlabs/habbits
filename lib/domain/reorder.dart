/// Returns a new list with the item at [oldIndex] moved to [newIndex].
///
/// [newIndex] is the destination index in the list *after* the dragged item is
/// removed — the convention of `ReorderableListView`'s `onReorderItem` callback,
/// which already accounts for the removal (unlike the deprecated `onReorder`,
/// which required the caller to decrement `newIndex` on downward moves). Does
/// not mutate [ids].
List<int> reorderedIds(List<int> ids, int oldIndex, int newIndex) {
  final list = [...ids];
  final item = list.removeAt(oldIndex);
  list.insert(newIndex, item);
  return list;
}

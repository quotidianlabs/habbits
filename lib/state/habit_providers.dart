import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/database.dart';
import '../data/habit_dao.dart';
import '../domain/models/habit_summary.dart';
import '../services/notification_service.dart';
import '../ui/habit_list/habit_list_view_model.dart';

part 'habit_providers.g.dart';

@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) =>
    throw UnimplementedError(
        'notificationServiceProvider must be overridden in main');

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

@riverpod
HabitDao habitDao(Ref ref) => ref.watch(appDatabaseProvider).habitDao;

/// A single habit's summary, derived from [habitListViewModelProvider]. Returns
/// null while loading or after the habit has been deleted.
@riverpod
HabitSummary? habitDetail(Ref ref, int habitId) {
  final summaries = ref.watch(habitListViewModelProvider).value;
  if (summaries == null) return null;
  for (final s in summaries) {
    if (s.habit.id == habitId) return s;
  }
  return null;
}

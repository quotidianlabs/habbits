import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/database.dart';
import '../data/habit_dao.dart';
import '../services/notification_service.dart';

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

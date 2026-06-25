import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/services/database/database.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _MockPathProvider extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {}

void main() {
  group('production constructor', () {
    test(
      'production constructor opens via openConnection (lazy, no executor)',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        final mockPathProvider = _MockPathProvider();
        when(
          () => mockPathProvider.getTemporaryPath(),
        ).thenAnswer((_) async => Directory.systemTemp.path);
        when(
          () => mockPathProvider.getApplicationDocumentsPath(),
        ).thenAnswer((_) async => Directory.systemTemp.path);
        PathProviderPlatform.instance = mockPathProvider;

        // No executor => the `: openConnection()` branch runs. driftDatabase is
        // lazy, so this builds without touching the filesystem.
        final db = AppDatabase();
        addTearDown(() async {
          try {
            await db.close();
          } catch (_) {
            /* lazy db may never have opened */
          }
        });
        expect(db, isA<AppDatabase>());
      },
    );
  });

  group('in-memory database', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('inserts and reads a habit', () async {
      final id = await db
          .into(db.habits)
          .insert(
            HabitsCompanion.insert(
              name: 'Medicine',
              color: 0xFF009688,
              sortOrder: 0,
              createdAt: DateTime(2026, 6, 13),
            ),
          );
      final row = await (db.select(
        db.habits,
      )..where((h) => h.id.equals(id))).getSingle();
      expect(row.name, 'Medicine');
    });

    test('rejects a duplicate (habitId, localDate)', () async {
      final habitId = await db
          .into(db.habits)
          .insert(
            HabitsCompanion.insert(
              name: 'Read',
              color: 1,
              sortOrder: 0,
              createdAt: DateTime(2026, 6, 13),
            ),
          );
      await db
          .into(db.completions)
          .insert(
            CompletionsCompanion.insert(
              habitId: habitId,
              localDate: '2026-06-13',
              createdAt: DateTime(2026, 6, 13),
            ),
          );

      await expectLater(
        () => db
            .into(db.completions)
            .insert(
              CompletionsCompanion.insert(
                habitId: habitId,
                localDate: '2026-06-13',
                createdAt: DateTime(2026, 6, 13),
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('deleting a habit cascades to its completions', () async {
      final habitId = await db
          .into(db.habits)
          .insert(
            HabitsCompanion.insert(
              name: 'Workout',
              color: 1,
              sortOrder: 0,
              createdAt: DateTime(2026, 6, 13),
            ),
          );
      await db
          .into(db.completions)
          .insert(
            CompletionsCompanion.insert(
              habitId: habitId,
              localDate: '2026-06-13',
              createdAt: DateTime(2026, 6, 13),
            ),
          );

      await (db.delete(db.habits)..where((h) => h.id.equals(habitId))).go();

      final remaining = await db.select(db.completions).get();
      expect(remaining, isEmpty);
    });
  });
}

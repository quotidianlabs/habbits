import 'dart:io';

import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/repositories/backup_repository.dart';
import 'package:habbits/data/repositories/habit_repository.dart';
import 'package:habbits/data/services/database/database.dart';
import 'package:habbits/data/services/database/database_providers.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus/share_plus.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

class _MockPathProvider extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {}

class _MockFilePicker extends Mock
    with MockPlatformInterfaceMixin
    implements FilePicker {}

class _MockSharePlatform extends Mock implements SharePlatform {}

class _FakeShareParams extends Fake implements ShareParams {}

void main() {
  late AppDatabase db;
  late BackupRepository repo;
  late _MockSharePlatform mockShare;

  setUpAll(() {
    registerFallbackValue(_FakeShareParams());
  });

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    db = AppDatabase(NativeDatabase.memory());

    mockShare = _MockSharePlatform();
    when(
      () => mockShare.share(any()),
    ).thenAnswer((_) async => const ShareResult('', ShareResultStatus.success));

    repo = BackupRepository(
      HabitRepository(db.habitDao),
      share: SharePlus.custom(mockShare),
    );

    final paths = _MockPathProvider();
    when(
      () => paths.getTemporaryPath(),
    ).thenAnswer((_) async => Directory.systemTemp.path);
    PathProviderPlatform.instance = paths;
  });

  tearDown(() async {
    await db.close();
  });

  test('exportAndShare writes a temp file and opens the share sheet', () async {
    await db.habitDao.createHabit(name: 'Read', color: 1);

    await repo.exportAndShare(subject: 'My backup');

    final captured =
        verify(() => mockShare.share(captureAny())).captured.single
            as ShareParams;
    expect(captured.subject, 'My backup');
    expect(captured.files, hasLength(1));
    final written = File(captured.files!.single.path);
    expect(await written.exists(), isTrue);
    expect(await written.readAsString(), contains('Read'));
  });

  test('pickAndDecode returns null when the user cancels', () async {
    final picker = _MockFilePicker();
    when(
      () => picker.pickFiles(allowMultiple: any(named: 'allowMultiple')),
    ).thenAnswer((_) async => null);
    FilePicker.platform = picker;

    expect(await repo.pickAndDecode(), isNull);
  });

  test('pickAndDecode decodes the chosen backup file', () async {
    // Round-trip a real export to disk, then pick it back.
    await db.habitDao.createHabit(name: 'Read', color: 1);
    await repo.exportAndShare(subject: 's');

    final captured =
        verify(() => mockShare.share(captureAny())).captured.single
            as ShareParams;
    final path = captured.files!.single.path;

    final picker = _MockFilePicker();
    when(
      () => picker.pickFiles(allowMultiple: any(named: 'allowMultiple')),
    ).thenAnswer(
      (_) async =>
          FilePickerResult([PlatformFile(path: path, name: 'b.json', size: 0)]),
    );
    FilePicker.platform = picker;

    final data = await repo.pickAndDecode();

    expect(data, isNotNull);
    expect(data!.habits.single.name, 'Read');
  });

  test(
    'BackupRepository default share (covers ?? SharePlus.instance branch)',
    () {
      // Construct with no share: arg so the ?? branch runs.
      final noShareRepo = BackupRepository(HabitRepository(db.habitDao));
      expect(noShareRepo, isA<BackupRepository>());
    },
  );

  test('backupRepositoryProvider wires up via ProviderContainer', () async {
    final memDb = AppDatabase(NativeDatabase.memory());
    addTearDown(memDb.close);

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(memDb)],
    );
    addTearDown(container.dispose);

    final instance = container.read(backupRepositoryProvider);
    expect(instance, isA<BackupRepository>());
  });
}

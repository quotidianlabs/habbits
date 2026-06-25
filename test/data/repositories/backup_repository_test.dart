import 'dart:io';

import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/repositories/backup_repository.dart';
import 'package:habbits/data/repositories/habit_repository.dart';
import 'package:habbits/data/services/database/database.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _MockPathProvider extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {}

class _MockFilePicker extends Mock
    with MockPlatformInterfaceMixin
    implements FilePicker {}

void main() {
  late AppDatabase db;
  late BackupRepository repo;

  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
  MethodCall? capturedShareCall;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    db = AppDatabase(NativeDatabase.memory());
    repo = BackupRepository(HabitRepository(db.habitDao));

    final paths = _MockPathProvider();
    when(
      () => paths.getTemporaryPath(),
    ).thenAnswer((_) async => Directory.systemTemp.path);
    PathProviderPlatform.instance = paths;

    capturedShareCall = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (call) async {
          capturedShareCall = call;
          // Any non-empty, non-unavailable string => ShareResultStatus.success
          return 'dev.fluttercommunity.plus/share/success';
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, null);
    await db.close();
  });

  test('exportAndShare writes a temp file and opens the share sheet', () async {
    await db.habitDao.createHabit(name: 'Read', color: 1);

    await repo.exportAndShare(subject: 'My backup');

    expect(capturedShareCall, isNotNull);
    expect(capturedShareCall!.method, 'share');
    final args = capturedShareCall!.arguments as Map;
    expect(args['subject'], 'My backup');
    final filePaths = args['paths'] as List;
    expect(filePaths, hasLength(1));
    final written = File(filePaths.single as String);
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
    final args = capturedShareCall!.arguments as Map;
    final path = (args['paths'] as List).single as String;

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
}

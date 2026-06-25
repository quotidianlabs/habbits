import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Opens the on-device SQLite database file. This is production I/O glue: it
/// cannot run under `flutter test` (no app-documents directory), so it is
/// excluded from unit coverage (see coverde.yaml) and exercised by the emulator
/// integration test instead.
QueryExecutor openConnection() => driftDatabase(name: 'habbits');

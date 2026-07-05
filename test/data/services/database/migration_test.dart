import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/services/database/database.dart';

import '../../../generated_migrations/schema.dart';

void main() {
  // At schemaVersion 1 this is a HARNESS-WIRING SMOKE, not a schema lock:
  // migrateAndValidate(db, 1) has no migration to run, so it cannot catch a
  // table changed without re-dumping (verified). Its value now is proving the
  // generated helpers compile and SchemaVerifier runs in habbits' test env.
  // When schemaVersion first reaches 2, migrateAndValidate(db, 2) becomes the
  // real schema + data validator (one-line change: 1 -> 2). The actual v1
  // schema lock is the CI `just schema-check` gate.
  test('current schema builds and validates via SchemaVerifier', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 1);
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every hand-written Dart file under [dir], paired with its import targets.
Map<String, List<String>> _importsUnder(String dir) {
  final result = <String, List<String>>{};
  for (final entity in Directory(dir).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('.g.dart')) continue;
    result[entity.path] = entity
        .readAsLinesSync()
        .where((line) => line.startsWith('import '))
        .map((line) => line.split("'")[1])
        .toList();
  }
  return result;
}

void main() {
  test('domain takes no direct Flutter or Drift import', () {
    // INVARIANT: pure logic stays free of the UI toolkit and the database library,
    // so it can be read and tested without either.
    //
    // Broken by reaching for a Flutter type in a domain file because it is
    // convenient - Color for a habit swatch, TimeOfDay for a reminder, or Drift's
    // expression builders to push a computation into SQL. Each one is individually
    // reasonable and collectively turns the date and streak logic into something
    // that only runs inside a widget test with a database attached. Drift arrives
    // transitively through the generated database library, which docs/adr/0001
    // permits; a direct package: import is the thing that does not come back.
    final offenders = <String>[];
    _importsUnder('lib/domain').forEach((path, imports) {
      for (final target in imports) {
        if (target.startsWith('package:flutter') ||
            target.startsWith('package:drift')) {
          offenders.add('$path -> $target');
        }
      }
    });

    expect(offenders, isEmpty);
  });

  test('the generated database library is the only data import in domain', () {
    // INVARIANT: domain depends on the database for row types and for nothing else.
    //
    // Broken by importing a repository or a DAO from a domain file to reach a query
    // that is already written - at which point pure functions start doing I/O and
    // the projection can no longer be exercised with a literal set of dates. Drift
    // rows are the domain model by docs/adr/0001, so this single import is the price
    // of having no mapper layer; a second one means the mapper is now owed.
    final offenders = <String>[];
    _importsUnder('lib/domain').forEach((path, imports) {
      for (final target in imports) {
        if (!target.contains('data/')) continue;
        if (target.endsWith('/database.dart')) continue;
        offenders.add('$path -> $target');
      }
    });

    expect(offenders, isEmpty);
  });

  test('nothing beneath domain or data imports the ui layer', () {
    // INVARIANT: the dependency arrow into the UI points one way, so a screen can be
    // rebuilt or deleted without a repository noticing.
    //
    // Broken by a repository or a domain helper reaching for a provider, a theme
    // token, or a localization lookup that happens to live under ui/ - the fastest
    // fix at the call site, and the one that makes the data layer unusable from a
    // plain Dart test. lib/main.dart is deliberately outside this rule: it is the
    // composition root and wires the screens together by definition.
    final offenders = <String>[];
    for (final dir in ['lib/domain', 'lib/data']) {
      _importsUnder(dir).forEach((path, imports) {
        for (final target in imports) {
          if (target.contains('ui/')) offenders.add('$path -> $target');
        }
      });
    }

    expect(offenders, isEmpty);
  });
}

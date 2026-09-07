import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Matches an `import`/`export` directive and captures its target, under either
/// quote style. `flutter_lints` does not enable `prefer_single_quotes`, so both
/// are legal here, and an `export` re-publishes a dependency to every importer
/// exactly as an `import` would.
final _directive = RegExp('''^\\s*(?:import|export)\\s+['"]([^'"]+)['"]''');

/// Every hand-written Dart file under [dir], paired with its dependency targets.
/// Relative targets are resolved against the importing file, so a check can ask
/// which directory a target actually lands in.
Map<String, List<String>> _dependenciesUnder(String dir) {
  final result = <String, List<String>>{};
  for (final entity in Directory(dir).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('.g.dart')) continue;
    final from = Uri.file(entity.absolute.path);
    result[entity.path] = entity
        .readAsLinesSync()
        .map((line) => _directive.firstMatch(line)?.group(1))
        .nonNulls
        .map(
          (target) =>
              target.startsWith('package:') || target.startsWith('dart:')
              ? target
              : from.resolve(target).toFilePath(),
        )
        .toList();
  }
  return result;
}

/// Files under any of [dirs] whose targets [offends], as `path -> target`.
/// Throws if a directory contributes no files: an empty scan would otherwise
/// make every check below pass without inspecting anything.
List<String> _violations(
  List<String> dirs,
  bool Function(String target) offends,
) {
  final violations = <String>[];
  for (final dir in dirs) {
    final scanned = _dependenciesUnder(dir);
    if (scanned.isEmpty) throw StateError('no Dart files found under $dir');
    scanned.forEach((path, targets) {
      for (final target in targets) {
        if (offends(target)) violations.add('$path -> $target');
      }
    });
  }
  return violations;
}

bool _isUnder(String target, String dir) =>
    target.contains('/$dir/') || target.endsWith('/$dir');

void main() {
  test('domain depends on no Flutter or Drift package', () {
    // INVARIANT: pure logic stays free of the UI toolkit and the database
    // library, so it can be read and tested without either.
    //
    // Broken by reaching for a Flutter type in a domain file because it is
    // convenient: Color for a habit swatch, TimeOfDay for a reminder, or Drift's
    // expression builders to push a computation into SQL. Each one is
    // individually reasonable and collectively turns the date and streak logic
    // into something that only runs inside a widget test with a database
    // attached. The whole ecosystem is excluded, not just the two root packages,
    // because flutter_riverpod in a pure function is the same mistake wearing a
    // different name. Drift still arrives transitively through the generated
    // database library, which docs/adr/0001 permits; a direct dependency is the
    // thing that does not come back.
    expect(
      _violations(
        ['lib/domain'],
        (target) =>
            target.startsWith('package:flutter') ||
            target.startsWith('package:drift'),
      ),
      isEmpty,
    );
  });

  test('the generated database library is the only data dependency in domain', () {
    // INVARIANT: domain depends on the database for row types and nothing else.
    //
    // Broken by importing a repository or a DAO from a domain file to reach a
    // query that is already written, at which point pure functions start doing
    // I/O and the projection can no longer be exercised with a literal set of
    // dates. Drift rows are the domain model by docs/adr/0001, so this single
    // dependency is the price of having no mapper layer; a second one means the
    // mapper is now owed.
    expect(
      _violations(
        ['lib/domain'],
        (target) =>
            _isUnder(target, 'data') && !target.endsWith('/database.dart'),
      ),
      isEmpty,
    );
  });

  test('nothing beneath domain or data depends on the ui layer', () {
    // INVARIANT: the dependency arrow into the UI points one way, so a screen
    // can be rebuilt or deleted without a repository noticing.
    //
    // Broken by a repository or a domain helper reaching for a provider, a theme
    // token, or a localization lookup that happens to live under ui/: the
    // fastest fix at the call site, and the one that makes the data layer
    // unusable from a plain Dart test. lib/main.dart is deliberately outside
    // this rule, being the composition root that wires the screens together.
    expect(
      _violations([
        'lib/domain',
        'lib/data',
      ], (target) => _isUnder(target, 'ui')),
      isEmpty,
    );
  });

  test('screens and widgets reach data only through a view model', () {
    // INVARIANT: a screen or a widget never holds a repository, a DAO or a
    // service. It watches a view model and calls its commands.
    //
    // Broken by a screen calling a repository directly for the one value its
    // view model does not expose yet, which is faster than threading the value
    // through and leaves the widget untestable without a live database. The
    // sibling repo resolved this differently and lets widgets hold rows, so the
    // divergence is deliberate rather than an oversight: see the Sibling repo
    // section of AGENTS.md. View models and the lifecycle controllers under
    // lib/ui/core/ are the intended holders and are exempt.
    final surfaces = _dependenciesUnder('lib/ui')
      ..removeWhere(
        (path, _) =>
            path.endsWith('_view_model.dart') || _isUnder(path, 'core'),
      );
    expect(surfaces, isNotEmpty);

    final violations = <String>[];
    surfaces.forEach((path, targets) {
      for (final target in targets) {
        if (_isUnder(target, 'data')) violations.add('$path -> $target');
      }
    });
    expect(violations, isEmpty);
  });
}

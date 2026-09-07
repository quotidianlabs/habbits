default: install lint test

install:
    flutter pub get

# auto-fixing (local)
lint:
    dart format .
    flutter analyze

# check-only (CI)
lint-ci:
    dart format --output=none --set-exit-if-changed .
    flutter analyze

test *args:
    flutter test {{ args }}

# tests with coverage; excludes generated + DB glue, gates the % (matches CI)
coverage:
    flutter test --coverage
    dart pub global run coverde transform --input coverage/lcov.info --output coverage/lcov.info --mode w --transformations preset=exclude-untestable
    dart pub global run coverde check --input coverage/lcov.info 100

# Dump the current Drift schema snapshot into drift_schemas/ (run after every
# schemaVersion bump, before schema-gen).
schema-dump:
    dart run drift_dev schema dump lib/data/services/database/database.dart drift_schemas/

# Regenerate the SchemaVerifier test helpers from the snapshots in
# drift_schemas/.
#
# WHEN schemaVersion FIRST REACHES 2, this recipe must also gain the
# steps generator, and database.dart must wire stepByStep + onUpgrade:
#     dart run drift_dev schema steps drift_schemas/ lib/data/services/database/database.steps.dart
# and add `**/database.steps.dart` to coverde.yaml (it lands in lib/, so it IS
# coverage-instrumented, unlike the test/ helpers).
schema-gen:
    dart run drift_dev schema generate --data-classes --companions drift_schemas/ test/generated_migrations/

# CI gate (the real schema lock): re-dump + regenerate, then fail if any schema
# artifact differs from what is committed — catches a schemaVersion bump with
# no committed snapshot, or generated files not regenerated. Porcelain (not
# `git diff`) so an untracked new snapshot counts as dirty too.
schema-check: schema-dump schema-gen
    #!/usr/bin/env bash
    set -euo pipefail
    paths="drift_schemas/ test/generated_migrations/"
    dirty=$(git status --porcelain -- $paths)
    if [ -n "$dirty" ]; then
      echo "::error::Schema artifacts are stale. Run 'just schema-dump' && 'just schema-gen' and commit the result."
      echo "$dirty"
      git --no-pager diff -- $paths
      exit 1
    fi

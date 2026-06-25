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

# Print the planning change index (grouped by status) to stdout.
index:
    python3 planning/index.py

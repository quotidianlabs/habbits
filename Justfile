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

# tests with coverage; prints the % excluding generated files (matches CI)
coverage:
    flutter test --coverage
    python3 tool/coverage.py

# Print the planning change index (grouped by status) to stdout.
index:
    python3 planning/index.py

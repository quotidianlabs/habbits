---
status: shipped
date: 2026-06-15
slug: ci-and-justfile
summary: GitHub Actions CI + Justfile (lint/test) with a repo-wide dart-format pass.
supersedes: null
superseded_by: null
pr: "3"
outcome: GitHub Actions CI + Justfile (lint/test) with a repo-wide dart-format pass.
---

# Design: CI + Justfile (lint/test) with a dart-format pass

## Summary

Add a `Justfile` (`install` / `lint` / `lint-ci` / `test`) mirroring the sibling
`pypi/*` repos, a GitHub Actions workflow that runs those `just` tasks
(`flutter analyze` + `flutter test`) on every push to `main` and every PR, and a
one-time `dart format` pass across the repo so the `lint-ci` format gate is
green. The single source of truth for "how to lint/test" becomes the `Justfile`,
used identically by a developer locally and by CI.

## Motivation

The now-public repo has **no CI** — no green-checkmark signal, no automatic
regression guard on PRs — and no consistent task entry points. The sibling repos
already standardize on a `Justfile` + a `just`-based CI; adopting the same here
keeps the workflow uniform across repos and gives the public repo the credibility
of passing checks.

## Non-goals

- **Codecov coverage upload** — deferred (tracked in `deferred.md`); keeps this
  change free of external-service setup.
- **Emulator integration-test job** — deferred; `integration_test/` needs a
  booted Android emulator (slow/flaky on CI) and the 115-test suite covers the
  logic.
- **`build_runner` in CI** — not needed; generated `*.g.dart` is committed.
- **Publishing / release workflows** — out of scope.

## Design

### 1. `Justfile` (repo root)

```just
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
```

`lint` mirrors `ruff format` (auto-fix); `lint-ci` mirrors `ruff format --check`
(fail on drift). `just` is installed locally via `brew install just` and in CI
via `extractions/setup-just`.

### 2. One-time `dart format` pass

Run `dart format .` once across the repo and commit the result as its own commit
(so the diff is reviewable in isolation). This makes `lint-ci`'s
`--set-exit-if-changed` pass. Generated `*.g.dart` files are formatted by their
generators already; `dart format` leaves them effectively unchanged. **This step
must not change behavior — only whitespace/layout — so the 115-test suite stays
green.**

### 3. CI workflow `.github/workflows/ci.yml`

```yaml
name: main

on:
  push:
    branches: [main]
  pull_request: {}

concurrency:
  group: ${{ github.head_ref || github.run_id }}
  cancel-in-progress: true

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: extractions/setup-just@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: 3.44.2
          channel: stable
          cache: true
      - run: just install lint-ci

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: extractions/setup-just@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: 3.44.2
          channel: stable
          cache: true
      - run: just install test
```

Pinned to **Flutter 3.44.2** (the repo targets a very new Flutter; pinning keeps
CI reproducible rather than tracking `stable`). Two jobs (`lint`, `test`) run in
parallel. A single `ci.yml` (no reusable `_checks.yml` split — that pays off only
when a `scheduled.yml` also reuses it, which this repo doesn't need yet).

## Operations

None beyond the workflow itself. The first push triggers the first CI run on
GitHub; we confirm it goes green.

## Testing

- `just lint-ci` and `just test` pass **locally** (after the format pass).
- `flutter analyze` clean, `flutter test` = 115 passing (the format pass must not
  break anything).
- `ci.yml` is valid YAML and actually runs — confirm the first green run on the
  PR.

## Risk

- **`dart format` diff is large** (many files) — likely, low impact: it's
  whitespace-only; mitigated by committing it as its own reviewable commit and by
  the test suite staying green.
- **CI red on first run** (version/setup mismatch) — medium impact: mitigated by
  validating `just lint-ci`/`just test` locally first and pinning the Flutter
  version; iterate on the PR until green before merge.
- **`extractions/setup-just` / action version drift** — low: pinned major
  versions.

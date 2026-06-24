---
status: draft
date: 2026-06-25
slug: coverage-in-ci
summary: Report + enforce test coverage in CI with no third-party service (PR comment, job summary, 80% gate).
supersedes: null
superseded_by: null
pr: null
outcome: null
---

# Change: Test coverage in CI (no third-party service)

**Lane:** lightweight — one new helper script + `ci.yml`/`Justfile` edits. No app
code, no public-API change.

## Goal

Surface and enforce test coverage on every CI run **without a third-party SaaS**
(no Codecov/Coveralls). Replaces the deferred "Codecov coverage upload" item with
a fully GitHub-native approach. Coverage today is **84.3%** excluding generated
files (65% including them — hence the exclusion).

## Approach

`flutter test --coverage` → `coverage/lcov.info`, then:

- **`tool/coverage.py`** — the single home for the generated-file exclusion list
  (`*.g.dart`, `*.freezed.dart`, `app_localizations*.dart`). It rewrites
  `lcov.info` in place (filtered) and prints a Markdown summary. Both
  `just coverage` (local) and CI run it, so the percentage is identical
  everywhere. Excluding generated matters: the Drift `database.g.dart` alone is
  148/555 lines and would drag the number down ~19 pts.
- **Job summary** — CI pipes the script's Markdown into `$GITHUB_STEP_SUMMARY`
  (visible on every run, including `main` pushes).
- **PR comment** — `romeovs/lcov-reporter-action@v0.4.0` posts a per-file table
  on pull requests via the built-in `GITHUB_TOKEN` (needs
  `permissions: pull-requests: write`). No service, no account.
- **Threshold gate** — `VeryGoodOpenSource/very_good_coverage@v3` fails CI below
  `min_coverage: 80` (Flutter-native). 80 sits ~4 pts under current so normal
  churn won't break CI; ratchet up later.
- **No badge** (decided) — avoids persisting state between runs; revisit if a
  README number is wanted (a `badges` branch is the native option).

## Files

- `tool/coverage.py` — new; filter generated files + emit Markdown summary.
- `.github/workflows/ci.yml` — `test` job: run with coverage, filter+summarize,
  gate at 80%, PR comment; adds `pull-requests: write`.
- `Justfile` — new `coverage` recipe (local run matching CI).
- `.gitignore` — ignore `coverage/`.
- `planning/deferred.md` — drop the now-addressed Codecov item.

## Verification

- [x] Local: `just coverage` → 84.3% (815/967), generated files removed from
      `lcov.info`.
- [ ] CI on the PR: `test` job green; job summary shows the coverage table.
- [ ] PR comment posted with the per-file breakdown.
- [ ] Gate passes at 84.3% ≥ 80; would fail if dropped below 80.
- [ ] `flutter analyze` clean; full suite green.

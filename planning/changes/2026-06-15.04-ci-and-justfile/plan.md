# ci-and-justfile — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A `Justfile` (`install`/`lint`/`lint-ci`/`test`) + a GitHub Actions CI running those tasks, with a one-time repo-wide `dart format` pass so the format gate is green.

**Spec:** [`design.md`](./design.md)

**Branch:** `chore/ci-and-justfile`

**Commit strategy:** Per-task commits.

**Conventions:**
- `export PATH="/opt/homebrew/bin:$PATH"` before flutter/dart/just. `just` 1.52.0 is installed locally.
- Stage explicit paths only (no `git add -A`).
- Gate every task: `flutter analyze` clean + `flutter test` = 115 passing.

**Pre-flight:**
```bash
export PATH="/opt/homebrew/bin:$PATH"
flutter analyze && flutter test   # baseline clean + 115
git switch -c chore/ci-and-justfile
```

---

## Task 1: One-time `dart format` pass

**Files:** every `.dart` file `dart format` rewrites (whitespace/layout only; ~34 files).

- [ ] **Step 1: Run the formatter**
```bash
export PATH="/opt/homebrew/bin:$PATH"
dart format .
```
Expected: "Formatted N files (M changed)".

- [ ] **Step 2: Confirm behavior is unchanged**
```bash
flutter analyze 2>&1 | tail -1
flutter test 2>&1 | tail -1
```
Expected: "No issues found!" and 115 pass. (Format is whitespace-only — if any test fails, something is wrong; STOP and report.)

- [ ] **Step 3: Confirm the tree is now fully formatted**
```bash
dart format --output=none --set-exit-if-changed . && echo "fully formatted ✓"
```
Expected: exit 0, "fully formatted ✓".

- [ ] **Step 4: Commit (its own reviewable commit)**
```bash
git add -u
git commit -m "style: dart format pass across the repo

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```
(`git add -u` stages only modifications to already-tracked files — no new/ignored files.)

---

## Task 2: Add the `Justfile`

**Files:** Create `Justfile` (repo root).

- [ ] **Step 1: Create `Justfile`**
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

- [ ] **Step 2: Verify the tasks run green locally**
```bash
export PATH="/opt/homebrew/bin:$PATH"
just lint-ci
just test
```
Expected: `lint-ci` → format check passes (no diff after Task 1) + analyze clean; `test` → 115 pass.

- [ ] **Step 3: Commit**
```bash
git add Justfile
git commit -m "chore: add Justfile (install/lint/lint-ci/test)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Add the CI workflow

**Files:** Create `.github/workflows/ci.yml`.

- [ ] **Step 1: Create `.github/workflows/ci.yml`**
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

- [ ] **Step 2: Validate the YAML parses**
```bash
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml')); print('yaml ok')"
```
Expected: "yaml ok".

- [ ] **Step 3: Commit**
```bash
git add .github/workflows/ci.yml
git commit -m "ci: run just lint-ci + test on push and PR (Flutter 3.44.2)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Final verification (+ first CI run on the PR)

**Files:** none.

- [ ] **Step 1: Full local gate**
```bash
export PATH="/opt/homebrew/bin:$PATH"
just lint-ci && just test
```
Expected: both green.

- [ ] **Step 2:** This change finishes via `finishing-a-development-branch` (push + PR). After pushing, **confirm the CI actually runs and goes green** on the PR (the `lint` and `test` jobs both pass) before merging. If CI is red, read the failing job log, fix on the branch, push, re-check — do not merge red.

- [ ] **Step 3: Done** — no commit (verification only).

---

## Self-Review notes (for the executor)

- **Spec coverage:** dart-format pass (T1), Justfile (T2), ci.yml (T3), local + first-green-run verification (T4). Single `ci.yml`, no codecov, Flutter pinned 3.44.2 — all per spec.
- **Behavior-preserving:** the format pass is whitespace-only; every task gates on 115 tests + analyze.
- **The format pass must land before/with the Justfile** so `lint-ci`'s `--set-exit-if-changed` is green.

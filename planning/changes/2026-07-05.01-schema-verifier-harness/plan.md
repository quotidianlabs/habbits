# schema-verifier-harness — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps
> use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install Drift's schema-snapshot migration harness in habbits at
schemaVersion 1 — a committed v1 snapshot, generated SchemaVerifier helpers, a
harness-wiring migration test, and a load-bearing `just schema-check` CI gate —
so the first real migration is forced through the tooling.

**Spec:** [`design.md`](./design.md)

**Branch:** `schema-verifier-harness` (already created; design already committed)

**Commit strategy:** Per-task commits.

## Global Constraints

- Flutter pinned `3.44.2`, Dart SDK `^3.12.2`; drift `^2.34.0`, `drift_dev`
  `^2.34.0` (dev-dep — must stay a dev-dep; never import it from `lib/`).
- Generated `*.g.dart` is committed; run
  `dart run build_runner build --delete-conflicting-outputs` after touching Drift
  code (only needed here for the throwaway fault-injection check in Task 1).
- `database.dart` is NOT modified by this change — there is no migration yet.
- The final pre-commit gate is `just lint-ci` (not `just lint`), plus `just test`
  and `just coverage` (100% gate). `dart format` must leave a clean tree.
- All facts below (toolchain runs green; the test is vacuous at v1; the gate
  bites; coverage stays 956/956 with no `coverde` change) were verified on this
  branch during a spike — the artifacts were regenerated so the tree is clean.

---

### Task 1: Install the harness and prove the gate bites

**Files:**
- Modify: `Justfile` (append three recipes after the `check-planning` recipe)
- Create: `drift_schemas/drift_schema_v1.json` (generated — do not hand-edit)
- Create: `test/generated_migrations/schema.dart`,
  `test/generated_migrations/schema_v1.dart` (generated — do not hand-edit)
- Create: `test/data/services/database/migration_test.dart`

Adds the developer + CI tooling, generates and commits the v1 snapshot and
SchemaVerifier helpers, and wires a green harness-smoke test. Ends with both
`flutter test` and `just schema-check` passing on the committed tree.

- [ ] **Step 1: Add the three schema recipes to `Justfile`**

  Append to the end of `Justfile` (after the `check-planning` recipe, line 33):

  ```just

  # Dump the current Drift schema snapshot into drift_schemas/ (run after every
  # schemaVersion bump, before schema-gen).
  schema-dump:
      dart run drift_dev schema dump lib/data/services/database/database.dart drift_schemas/

  # Regenerate the SchemaVerifier test helpers from the snapshots in
  # drift_schemas/.
  #
  # WHEN schemaVersion FIRST REACHES 2, this recipe must also gain the steps
  # generator, and database.dart must wire the stepByStep helper + onUpgrade
  # (see planning/changes/2026-07-05.01-schema-verifier-harness/design.md §5):
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
  ```

- [ ] **Step 2: Generate the v1 snapshot and helpers**

  Run: `just schema-dump && just schema-gen`
  Expected: `Wrote to drift_schemas/drift_schema_v1.json` then
  `Wrote 2 files into test/generated_migrations`. Confirm the files exist:
  `ls drift_schemas/ test/generated_migrations/` shows
  `drift_schema_v1.json`, `schema.dart`, `schema_v1.dart`. Confirm the helper is
  single-version: `grep versions test/generated_migrations/schema.dart` shows
  `static const versions = const [1];`.

- [ ] **Step 3: Write the harness-wiring migration test**

  Create `test/data/services/database/migration_test.dart`:

  ```dart
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
      await verifier.migrateAndValidate(db, 1);
      await db.close();
    });
  }
  ```

- [ ] **Step 4: Run the new test — expect PASS**

  Run: `flutter test test/data/services/database/migration_test.dart`
  Expected: `+1: All tests passed!` (proves the toolchain is wired).

- [ ] **Step 5: Commit the harness (establishes the committed baseline)**

  ```bash
  git add Justfile drift_schemas/ test/generated_migrations/ test/data/services/database/migration_test.dart
  git commit -m "chore(db): schema-verifier harness (snapshot + helpers + gate recipes)"
  ```

- [ ] **Step 6: Confirm `just schema-check` is GREEN on the committed tree**

  Run: `just schema-check`
  Expected: exit 0, no `::error::` output. (A fresh re-dump matches the committed
  snapshot; porcelain is clean.) If it fails with untracked/dirty output, the
  artifacts were not fully committed in Step 5 — commit them and re-run.

- [ ] **Step 7: Fault-injection — prove the gate BITES (throwaway, not committed)**

  Add a probe column to `lib/data/services/database/tables.dart`, inside the
  `Habits` table after `createdAt`:

  ```dart
    DateTimeColumn get createdAt => dateTime()();
    TextColumn get faultInjectionProbe => text().nullable()();
  ```

  Then:

  ```bash
  dart run build_runner build --delete-conflicting-outputs
  just schema-check   # EXPECT: fails with "::error::Schema artifacts are stale" (exit 1)
  ```

  The re-dump rewrites `drift_schema_v1.json` with the new column, so porcelain
  is dirty and the gate fails — this is the real v1 lock working.

- [ ] **Step 8: Revert the fault injection and confirm green again**

  ```bash
  git checkout -- lib/data/services/database/tables.dart
  dart run build_runner build --delete-conflicting-outputs
  git checkout -- drift_schemas/ test/generated_migrations/   # discard the dirtied re-dump
  just schema-check   # EXPECT: exit 0, clean
  git status --short  # EXPECT: empty (clean tree)
  ```

  Record in the task report: schema-check green on clean tree, red on the probed
  schema, green again after revert.

---

### Task 2: Add the CI `schema` job

**Files:**
- Modify: `.github/workflows/ci.yml` (insert a `schema` job between `test` and
  `integration`)

Runs `just schema-check` in CI so a stale snapshot fails the build.

- [ ] **Step 1: Insert the `schema` job**

  In `.github/workflows/ci.yml`, insert between the `test` job's last line
  (`dart pub global run coverde check --input coverage/lcov.info 100`, line 45)
  and the `# Runs the critical-flow integration test` comment (line 47):

  ```yaml

    # Fails if the committed schema snapshots / generated migration helpers are
    # not current — a schemaVersion bump without a dumped snapshot, or generated
    # files not regenerated. Keeps the SchemaVerifier harness trustworthy.
    schema:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v5
        - uses: extractions/setup-just@v4
        - uses: subosito/flutter-action@v2
          with:
            flutter-version: 3.44.2
            channel: stable
            cache: true
        - run: flutter pub get
        - run: just schema-check
  ```

- [ ] **Step 2: Sanity-check the YAML parses**

  Run: `python3 -c "import yaml,sys; d=yaml.safe_load(open('.github/workflows/ci.yml')); print(sorted(d['jobs']))"`
  Expected: `['integration', 'lint', 'schema', 'test']`

- [ ] **Step 3: Commit**

  ```bash
  git add .github/workflows/ci.yml
  git commit -m "ci(db): run just schema-check as a CI gate"
  ```

---

### Task 3: Promote to architecture, record the deferred item, finalize the spec, run final gates

**Files:**
- Modify: `architecture/habit-tracking.md:19` (extend the `database.dart` bullet)
- Create: `planning/deferred.md`
- Modify: `planning/changes/2026-07-05.01-schema-verifier-harness/design.md`
  (finalize `summary:` to the realized result)

Same-PR promotion required by the planning convention, plus the deferred
runtime-guard note the spec references, then the full gate run.

- [ ] **Step 1: Extend the `database.dart` code-map bullet in `architecture/habit-tracking.md`**

  Replace line 19:

  ```markdown
  - `lib/data/services/database/database.dart` — Drift schema (`Habits`, `Completions` tables) and `AppDatabase` wiring
  ```

  with:

  ```markdown
  - `lib/data/services/database/database.dart` — Drift schema (`Habits`, `Completions` tables) and `AppDatabase` wiring. The schema is snapshotted per version in [`drift_schemas/`](../drift_schemas) and locked by CI: `just schema-check` re-dumps and fails if a table changed without a committed snapshot (a `SchemaVerifier` test in `test/data/services/database/migration_test.dart` is only a wiring smoke at schemaVersion 1, becoming the real validator once a migration exists). Per-bump ritual: `just schema-dump` + `just schema-gen`; the first time `schemaVersion` reaches 2, also wire `stepByStep`/`onUpgrade` here and add `**/database.steps.dart` to `coverde.yaml` — see [`schema-verifier-harness`](../planning/changes/2026-07-05.01-schema-verifier-harness/design.md).
  ```

- [ ] **Step 2: Create `planning/deferred.md`**

  ```markdown
  # Deferred

  Real-but-unscheduled items. Each carries a revisit trigger — the condition
  that should bring it back onto the board.

  ## Runtime schema self-check (`validateDatabaseSchema` in `beforeOpen`)

  Drift can validate the live database against its declared schema at startup via
  `validateDatabaseSchema()`. We deliberately did not adopt it with the
  schema-verifier harness (see
  [`changes/2026-07-05.01-schema-verifier-harness/design.md`](changes/2026-07-05.01-schema-verifier-harness/design.md)):
  it is imported from `drift_dev`, so calling it from `lib/` pulls the analyzer /
  build stack into the app's *runtime* dependency graph. The CI `schema-check`
  gate already covers schema-drift.

  **Revisit trigger:** we want a debug-build, app-startup schema self-check
  (e.g. after a migration bug slips past CI) and have confirmed a way to invoke
  `validateDatabaseSchema` without adding `drift_dev` to runtime deps.
  ```

- [ ] **Step 3: Finalize the spec `summary:`**

  The `summary:` frontmatter in `design.md` is written as intent; finalize it to
  the realized result. Replace the existing `summary:` line with:

  ```markdown
  summary: Installed Drift's schema-snapshot migration harness at schemaVersion 1 — a committed v1 snapshot (drift_schemas/), generated SchemaVerifier helpers, a harness-wiring migration test, and a load-bearing `just schema-check` CI gate (the real schema lock; the test is vacuous until a migration exists). No coverde or database.dart change needed; forces the first migration through the tooling.
  ```

- [ ] **Step 4: Run the full gate suite**

  Run each and confirm:
  - `just lint-ci` → clean (format unchanged, analyze clean, planning index OK)
  - `just test` → all pass
  - `just coverage` → `GLOBAL: 100.00% - 956/956` (no `coverde` change)
  - `just check-planning` → `planning: OK`

- [ ] **Step 5: Commit**

  ```bash
  git add architecture/habit-tracking.md planning/deferred.md planning/changes/2026-07-05.01-schema-verifier-harness/design.md
  git commit -m "docs(db): promote schema harness to architecture + deferred runtime guard"
  ```

---

## Done when

- `just schema-check`, `just test`, `just coverage` (100%), `just lint-ci`, and
  `just check-planning` all pass on a clean, committed tree.
- `drift_schemas/drift_schema_v1.json`, `test/generated_migrations/`, and the
  migration test are committed; `Justfile` has the three recipes; `ci.yml` has
  the `schema` job; `architecture/habit-tracking.md` documents the ritual;
  `planning/deferred.md` records the runtime-guard item; the spec `summary:` is
  finalized.
- Ready to push and open a PR (per the author's PR-only workflow).

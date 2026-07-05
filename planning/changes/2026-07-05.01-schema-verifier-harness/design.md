---
summary: Install Drift's schema-snapshot migration harness preventively while the DB is still at schemaVersion 1 — a committed v1 snapshot, generated SchemaVerifier helpers, a schema-lock migration test, and a CI schema-check gate — so habbits' first real migration is forced through the tooling instead of a hand-written fixture.
---

# Design: Preventive schema-verifier migration harness

**Lane:** Full — new files (`drift_schemas/`, `test/generated_migrations/`, a new
migration test), a new CI job, and non-trivial test design (Drift
`SchemaVerifier` wiring).

## Summary

Install Drift's official schema-snapshot migration harness in habbits **now**,
while `AppDatabase.schemaVersion == 1` and the database has never migrated. We
commit a JSON snapshot of the current schema (`drift_schemas/drift_schema_v1.json`),
generate `SchemaVerifier` helpers into `test/generated_migrations/`, add a
harness-wiring migration test, and add the **load-bearing** `just schema-check`
CI gate — a re-dump-and-diff that fails if a schema change lands without a
re-committed snapshot. This is the
same harness the sibling project nooka adopted after its first migration, ported
here as a clean-slate **preventive** install so habbits' first real migration is
forced through generated snapshots and the CI gate rather than a hand-written
raw-SQL fixture. `database.dart` is not touched — there is no `onUpgrade` to
convert yet.

## Motivation

habbits stores all state in a Drift (SQLite) database with a `UNIQUE(habitId,
localDate)` completion constraint and a dense `sortOrder` per habit — a schema
that will inevitably change (a new habit field, a settings table, an archive
flag). Today the only schema test is a 21-line onCreate smoke test
(`test/data/services/database/schema_test.dart`) that proves the tables build; it
gives **zero** protection for the first migration.

nooka hit exactly this: it shipped its first migration (schemaVersion 1→2) with a
single hand-written test that fabricated a v1 database from **hand-typed raw-SQL
DDL** and asserted specific columns. That approach drifts from what Drift actually
generates and does not scale — each new version needs another hand fixture, and
nothing checks the migrated schema matches the declared tables *in full*. nooka
then replaced it with Drift's `SchemaVerifier`, whose snapshots are generated from
the real schema and whose `migrateAndValidate` compares the whole migrated schema
automatically for every version pair.

habbits should not repeat nooka's detour. Installing the harness at v1 — before
the first migration — means the migration author inherits generated snapshots and
a green CI gate on day one, and the first migration is authored the right way
from the start.

## Non-goals

- **Runtime `validateDatabaseSchema()` in `beforeOpen`.** It is imported from
  `drift_dev`, which would pull the analyzer/build stack into the app's *runtime*
  dependency graph. The CI harness covers the same schema-drift risk. Deferred
  (recorded in `planning/deferred.md`), revisit trigger: if we ever want a
  dev-build app-startup schema self-check.
- **A `stepByStep` / `database.steps.dart` migration helper now.** With a single
  schema version there are no migration steps to emit; `database.dart` keeps its
  current `MigrationStrategy` (just `beforeOpen`). The `stepByStep` wiring is
  authored with the first real migration — see Design §5.
- **A `build.yaml` / `make-migrations` wrapper.** We use the explicit `schema
  dump` / `schema generate` commands, which produce identical artifacts without a
  `build.yaml`. Can be adopted later with no rework.

## Design

### 1. Schema snapshot — `drift_schemas/` (committed)

One JSON snapshot, produced by:

```
dart run drift_dev schema dump lib/data/services/database/database.dart drift_schemas/
```

The command writes `drift_schema_v<N>.json` keyed by the code's current
`schemaVersion`, so at v1 it emits `drift_schemas/drift_schema_v1.json`. Because
v1 **is** the current schema, this is a straight dump from `main` — no throwaway
git-worktree checkout of an older commit (which nooka needed only to recover its
already-superseded v1).

### 2. Generated harness — `test/generated_migrations/` (committed; under `test/`, not coverage-instrumented)

```
dart run drift_dev schema generate --data-classes --companions drift_schemas/ test/generated_migrations/
```

generates:

- `schema.dart` — the `GeneratedHelper` (a `SchemaInstantiationHelper`) that
  `SchemaVerifier` consumes; at v1 its `versions` list is `[1]`.
- `schema_v1.dart` — the versioned `DatabaseAtV1` class plus data classes and
  companions. The `--data-classes --companions` flags make it usable for typed
  row round-trips in future data-integrity tests.

### 3. Migration test — `test/data/services/database/migration_test.dart` (new)

Placed under the mirrored-lib test path habbits uses (alongside the existing
`schema_test.dart`), using the test-only import
`package:drift_dev/api/migrations_native.dart` (so `drift_dev` stays a **dev**
dependency). The exact API shape below is copied verbatim from nooka's shipped
`migration_test.dart` and **verified to run green in habbits** (see Testing):

```dart
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/data/services/database/database.dart';

import '../../../generated_migrations/schema.dart';

void main() {
  // At schemaVersion 1 this is a HARNESS-WIRING SMOKE, not a schema lock:
  // migrateAndValidate(db, 1) has no migration to run, so it cannot catch a
  // table change made without re-dumping (verified — see design Testing). Its
  // value now is proving the generated helpers compile and SchemaVerifier runs
  // in habbits' test env. When schemaVersion first reaches 2, migrateAndValidate
  // (db, 2) becomes the real schema+data validator (one-line change: 1 -> 2).
  test('current schema builds and validates via SchemaVerifier', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    await verifier.migrateAndValidate(db, 1);
    await db.close();
  });
}
```

**What actually locks the schema is §4's `just schema-check`, not this test.**
Empirically (spike, this branch): adding a nullable column to `Habits` without
re-dumping left `migrateAndValidate(db, 1)` **green** — a single-version verify is
vacuous. The same divergence, however, makes `schema-check`'s re-dump rewrite
`drift_schema_v1.json` (the probe column appeared in the JSON), so the porcelain
diff fails the CI job. The existing `schema_test.dart` onCreate smoke test stays
as-is (cheap, independent).

### 4. Developer workflow + CI gate

`Justfile` gains three recipes (ported from nooka, minus the `schema steps`
line):

```
# Dump the current schema snapshot into drift_schemas/ (run after bumping
# schemaVersion, before generating).
schema-dump:
    dart run drift_dev schema dump lib/data/services/database/database.dart drift_schemas/

# Regenerate SchemaVerifier test helpers from the snapshots in drift_schemas/.
#
# When schemaVersion first reaches 2, this recipe MUST also gain the steps
# generator, and database.dart must wire the stepByStep helper (see §5):
#   dart run drift_dev schema steps drift_schemas/ lib/data/services/database/database.steps.dart
schema-gen:
    dart run drift_dev schema generate --data-classes --companions drift_schemas/ test/generated_migrations/

# CI gate: re-dump + regenerate, then fail if any schema artifact is stale —
# catches a schemaVersion bump with no committed snapshot, or generated files
# not regenerated. Porcelain (not `git diff`) so untracked new snapshots count.
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

`.github/workflows/ci.yml` gains a `schema` job mirroring nooka's: checkout,
`setup-just`, `flutter-action@v2` (pinned `3.44.2`, matching habbits' other
jobs), `flutter pub get`, `just schema-check`.

`coverde.yaml` gains one skip-glob, `**/test/generated_migrations/**`, alongside
the existing `*.g.dart` / `*.freezed.dart` exclusions, so the 100% line-coverage
gate holds against the generated helpers. (No `database.steps.dart` glob yet — it
does not exist until the first migration; adding it is part of the §5 checklist.)

### 5. The first-migration checklist (baked in now, executed later)

Route A defers exactly **two one-line config edits** to the day `schemaVersion`
first reaches 2. Both are pre-documented so nothing rests on memory: as a comment
above `schema-gen` in the `Justfile` (shown in §4) **and** in
`architecture/habit-tracking.md`. When the first migration lands, in that same
PR:

1. Add the `schema steps` line to the `schema-gen` recipe (shown commented in §4).
2. Add `**/database.steps.dart` to `coverde.yaml`.

Then the migration itself (unavoidable in any harness design): write the real
`stepByStep(from1To2: ...)` body against the **pinned** v2 schema, wire
`onUpgrade: _upgrade` into `MigrationStrategy`, run `just schema-dump` +
`just schema-gen`, and extend `migration_test.dart` with a data-integrity case
(insert a v1 row, migrate, assert it survived with new columns defaulted). At
that point the harness is byte-identical to nooka's.

## Operations

None. No infra, no store, no runtime behavior change — `database.dart` is not
modified. Pure test/tooling + CI addition.

## Out of scope

See Non-goals: the runtime `validateDatabaseSchema()` guard, a
`build.yaml`/`make-migrations` wrapper, and any `stepByStep`/`database.steps.dart`
helper (there is no migration to step through yet).

## Testing

Already verified on this branch (spike), so the plan builds on facts, not hopes:

- **Toolchain runs in habbits.** `just schema-dump` + `just schema-gen` produced
  `drift_schema_v1.json` and a `GeneratedHelper` with `versions=[1]`;
  `migration_test.dart` runs **green** under `flutter test`.
- **The real gate bites; the test does not (at v1).** Fault injection: a nullable
  `Habits` column added without re-dumping left `migrateAndValidate(db, 1)` green
  (single-version verify is vacuous), while a re-dump wrote the new column into
  `drift_schema_v1.json` — so `schema-check`'s porcelain diff is what fails CI.
  This is why §3 frames the test as a wiring smoke and §4's `schema-check` as the
  lock.

Still to confirm in the implementing PR:

- `just schema-check` **green on the committed clean tree**, then red after a
  hand-dirtied snapshot — closing the loop with the snapshots actually committed
  (the spike ran before commit, so `git status` showed them untracked).
- `just test` full suite green; `just coverage` stays at the 100% gate (generated
  `test/generated_migrations/**` excluded; no production line added);
  `just lint-ci` clean; `just check-planning` OK.

## Risk

- **~~`schema generate` on a single snapshot emits a degenerate helper~~**
  (RESOLVED by the spike): the helper generates and the test runs green. The real
  residual — that the test is *vacuous* at v1 — is not a risk but a documented
  property: §3 labels it a wiring smoke and the load-bearing lock is
  `schema-check`, which the spike confirmed bites.
- **The deferred two-line checklist is skipped at the first migration** (low ×
  medium): mitigated by baking it into the `Justfile` comment and
  `habit-tracking.md`; and `just schema-check` fails loudly the moment a v2 bump
  ships without its dumped snapshot, so the omission cannot land silently.
- **Coverage gate breaks on the generated files** (low × low): the `coverde.yaml`
  glob is added in the same change and verified by `just coverage`.

## Architecture docs to update (same PR)

- `architecture/habit-tracking.md` — at the `database.dart` bullet, note that the
  schema is snapshotted in `drift_schemas/` and locked by a `SchemaVerifier`
  migration test; state the per-migration ritual and the two-line first-migration
  checklist from §5.

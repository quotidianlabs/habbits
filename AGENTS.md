# AGENTS.md

Guidance for AI agents (Claude Code, etc.) working in this repository.

## Project Overview

Habbits is a local-first habit tracker for iOS and Android, in English and Russian - Flutter,
Riverpod for state, Drift (SQLite) on device, no backend and no cloud sync.
[`CONTEXT.md`](CONTEXT.md) says what it is and owns the vocabulary - read it before naming a
concept in code, a test name, or an issue title.

## Commands

`just` (task runner) and `flutter`. The [`Justfile`](Justfile) is the source of truth
`just --list`, or read it. The two things it does not say: generated `*.g.dart` is committed, so
run `dart run build_runner build --delete-conflicting-outputs` after touching `@riverpod` or
Drift code; and `just coverage` gates at 100%, with the only non-generated exclusions being the
database connection and its provider wiring (see
[`docs/adr/0006-platform-glue-is-mocked-not-coverage-excluded.md`](docs/adr/0006-platform-glue-is-mocked-not-coverage-excluded.md)).

## Architecture

Layered MVVM. `lib/ui/` holds screens, Riverpod view models and widgets; `lib/domain/` holds
pure logic and models; `lib/data/` holds repositories over a Drift DAO plus the platform
services. Each file is named for what it does; read it.

The layer rule is narrower than the usual formulation, because Drift rows *are* the domain
models: there is no mapper layer, so `lib/domain/` depends on the generated database library on
purpose. What actually holds, and what `test/architecture_test.dart` enforces:

- `lib/domain/` depends on no Flutter- or Drift-ecosystem package. The whole ecosystem, not just
  the two root packages: `flutter_riverpod` in a pure function is the same mistake.
- Its only `lib/data/` dependency is the generated database library.
- Nothing under `lib/domain/` or `lib/data/` depends on `lib/ui/`.
- Screens and widgets reach data only through a view model; view models and the lifecycle
  controllers under `lib/ui/core/` are the intended holders.

`lib/main.dart` is the composition root and sits outside all of it. Those checks read `export`
as well as `import`, because a re-export propagates the same coupling.
[`docs/adr/0001-drift-rows-are-the-domain-model.md`](docs/adr/0001-drift-rows-are-the-domain-model.md)
is why, and is worth reading before "fixing" that dependency.

What a single-file read will **not** tell you:

- **`currentDayProvider` (`lib/ui/core/current_day.dart`) is the only source of "today".** It
  ticks at local midnight and on resume. No view reads the wall clock, and the home check-off
  writes the provider's day rather than `DateTime.now()` - so a tap in the midnight window
  before the ticker fires still lands on the day the user can see. A new surface that needs
  today must watch the provider; reaching for the clock reintroduces the bug.
- **`HabitSummary.from` is the only construction path for a summary**, and it normalizes `today`
  and every completion date to date-only, so no caller has to. The calendar builders
  (`buildHeatmap`, `recentDays`) deliberately stay outside it as pure functions taking
  view-specific layout counts - see
  [`docs/adr/0002-the-habit-projection-stays-scalar-only.md`](docs/adr/0002-the-habit-projection-stays-scalar-only.md)
  before absorbing them.
- **The reminder schedule is derived, never stored.** Every sync cancels everything and rebuilds
  from scratch; notification ids are positional, which is only safe *because* of the cancel-all.
  The policy - coalescing, the once-per-session permission gate, the two order-sensitive
  sequences - lives in the plain-Dart `ReminderSync` (`lib/ui/core/reminder_sync.dart`), not in
  `ReminderCoordinator`, which is a lifecycle adapter that renders its child unchanged. New
  scheduling logic goes in the controller, where it can be tested without pumping a widget.
- **`decodeBackup` validates the whole file before anything is written**, and `importReplace`
  runs as one transaction. A rejected file leaves the database untouched; import is replace-all,
  never a merge.
- **The schema is locked by CI, not by convention.** `just schema-check` re-dumps and
  regenerates, then fails if the committed artifacts in `drift_schemas/` differ. The `Justfile`
  records the extra ritual owed the first time `schemaVersion` reaches 2.

## Sibling repo

[`quotidianlabs/nooka`](https://github.com/quotidianlabs/nooka) is this app's sibling - same
stack, same shape, built from the same lineage. **Tooling is kept in sync deliberately**: CI
workflows, the release pipeline, the `Justfile`, coverage configuration and lint configuration.
A change to any of those here is owed to nooka too, and vice versa.

Features and architecture are **divergent by design** and are not ported: nooka has cloud backup
and recurring tasks, this app has reminders and streaks, and the two resolved the
Drift-rows-as-models trade-off differently (nooka lets widgets hold rows; this app wraps them in
a projection).

## Workflow

Real work **not scheduled** becomes a GitHub issue.

An invariant is a test whose name is the claim, with a comment opening `INVARIANT:` and a second
paragraph naming **what breaks it** - design rationale, not a report of what this one test
catches; a sibling test may be the one that trips. Nothing enforces that shape; it is read at
review time.

## Code Style

- Type-check and format through `just lint`; CI runs `just lint-ci`.
- Views `ref.watch` a view model and call its command methods; shared widgets in
  `lib/ui/widgets/` take values and return user input, and the screen acts on it. Feature-local
  widgets under `lib/ui/<feature>/widgets/` may read providers.
- All user-facing copy comes from `AppLocalizations`; the brand name, habit names and JSON keys
  are deliberately not in the ARB files.

## Agent skills

- **Issues and specs** - GitHub Issues on `quotidianlabs/habbits`, via `gh`:
  [`docs/agents/issue-tracker.md`](docs/agents/issue-tracker.md)
- **Triage labels** - the five canonical roles: [`docs/agents/triage-labels.md`](docs/agents/triage-labels.md)
- **Domain docs** - single-context, `CONTEXT.md` + `docs/adr/`: [`docs/agents/domain.md`](docs/agents/domain.md)

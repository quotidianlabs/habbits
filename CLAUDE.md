# Habbits — project guide

Local-first habit tracker (Flutter, iOS + Android, English + Russian). No
backend, no cloud sync — state lives in a Drift (SQLite) database on device,
managed with Riverpod.

## Architecture

Layered MVVM. `architecture/` (repo root) is the living truth home — one file
per capability. **When a change alters a capability's behavior, update the
matching `architecture/<capability>.md` in the same PR.** Start at
[`architecture/README.md`](architecture/README.md) for the layer map and
conventions.

Invariants that must not break:

- Dependency direction: `ui/` → `domain/` + `data/`; `domain/` imports neither
  Flutter nor Drift and is independently unit-testable; nothing imports `ui/`.
- A widget never imports a repository, DAO, service, or `database.dart` — views
  `ref.watch` a view model; shared widgets in `lib/ui/widgets/` are pure.
- Drift entities are used directly as domain models — no mapper layer.
- A completion is keyed `(habitId, localDate)` with a DB `UNIQUE` constraint;
  every habit carries an explicit dense integer `sortOrder`.

Capability → truth-home file:

| Capability | File |
|------------|------|
| Habit tracking (create/edit/check-off/reorder) | [`architecture/habit-tracking.md`](architecture/habit-tracking.md) |
| Streaks & stats (streak, completion %, heatmap) | [`architecture/streaks-and-stats.md`](architecture/streaks-and-stats.md) |
| Reminders (per-habit local notifications) | [`architecture/reminders.md`](architecture/reminders.md) |
| Backup I/O (JSON export / import) | [`architecture/backup-io.md`](architecture/backup-io.md) |
| i18n (English + Russian, live switch) | [`architecture/i18n.md`](architecture/i18n.md) |
| Theming (light/dark Material 3 + brand color) | [`architecture/theming.md`](architecture/theming.md) |

## Workflow

Design + plan for every non-trivial change live in `planning/`. Read
[`planning/README.md`](planning/README.md)'s Quick path to choose a lane (Full /
Lightweight / Tiny), create a change file, and ship — that file is the authoritative
convention. Run `just index` for the generated change listing and
`just check-planning` to validate changes (CI runs it via `just lint-ci`).

Decisions taken without code (esp. options rejected with a load-bearing reason)
go in `planning/decisions/`. Real-but-unscheduled items live in
`planning/deferred.md`.

## Commands

`just --list` is the source of truth. `just lint` (`dart format` +
`flutter analyze`) and `just test` (`flutter test`); CI uses `just lint-ci`.
Generated `*.g.dart` is committed — run
`dart run build_runner build --delete-conflicting-outputs` after touching
`@riverpod`/Drift code.

Non-obvious pointers:

- Local device/emulator setup and the `integration_test/` suite (platform
  gotchas) — [`docs/development.md`](docs/development.md).
- README screenshots are generated, not hand-captured —
  [`docs/screenshots.md`](docs/screenshots.md).
- Cutting an Android release build (`.aab`, signing, versionCode, target API) —
  [`docs/release.md`](docs/release.md).
</content>
</invoke>

# Habbits — project guide

Local-first habit tracker (Flutter, iOS + Android, English + Russian).
Architecture: layered MVVM with Riverpod — see the shipped change bundles in
`planning/`.

## Workflow

Design + plan for every non-trivial change live in `planning/`. Read
`planning/README.md` for the full convention. In short:

- A change is a bundle `planning/changes/active/YYYY-MM-DD.NN-<slug>/` with
  `design.md` + `plan.md` (Full lane) or `change.md` (Lightweight); on merge it
  moves to `planning/changes/archive/`.
- Real-but-unscheduled items live in `planning/deferred.md`.
- The `architecture/` capability docs live at the repo root (one file per
  capability) and are the living truth-home for what the system does now.

## Commands

`just lint` (`dart format` + `flutter analyze`) and `just test` (`flutter test`,
130 tests) — see the `Justfile`; CI uses `just lint-ci`. Generated `*.g.dart` is
committed; run `dart run build_runner build --delete-conflicting-outputs` after
touching `@riverpod`/Drift code.

README screenshots are generated, not hand-captured — see
[`docs/screenshots.md`](docs/screenshots.md) to regenerate or add shots.

Cutting an Android release build (`.aab`, signing, versionCode, target API) —
see [`docs/release.md`](docs/release.md).

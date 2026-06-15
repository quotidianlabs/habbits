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

`flutter analyze` and `flutter test` (115 tests) — a `Justfile` (`just lint` /
`just test`) is forthcoming. Generated `*.g.dart` is committed; run
`dart run build_runner build --delete-conflicting-outputs` after touching
`@riverpod`/Drift code.

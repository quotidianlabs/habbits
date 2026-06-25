# Architecture

Habbits is a local-first habit tracker built with Flutter, targeting iOS and Android, with English and Russian localization. State is managed with Riverpod and persisted in a Drift (SQLite) database on device — there is no backend or cloud sync. The app follows a layered MVVM pattern with a strict dependency direction: `ui/` depends on `domain/` and `data/`; `domain/` has no Flutter or Drift imports and is independently unit-testable.

## Layer map

| Layer | Path | Role |
|-------|------|------|
| UI | `lib/ui/` | Screens, view models (Riverpod notifiers), and widgets |
| Domain | `lib/domain/` | Pure logic and models — no Flutter, no Drift; independently unit-testable |
| Data | `lib/data/` | Repositories over a Drift DAO plus platform services (notifications, file I/O) |

`ui/` imports from both `domain/` and `data/`. `domain/` imports from neither. `data/` imports `domain/` models; nothing imports from `ui/`.

## Capabilities

| Capability | What it covers |
|------------|----------------|
| [Habit tracking](habit-tracking.md) | Create / edit / check-off / reorder habits, persisted in Drift |
| [Streaks & stats](streaks-and-stats.md) | Current streak, completion %, heatmap, recent-days strip |
| [Reminders](reminders.md) | Per-habit local notifications scheduled on device |
| [Backup I/O](backup-io.md) | JSON export / import with strict validation |
| [i18n](i18n.md) | English + Russian localization (live switch, no restart required) |
| [Theming](theming.md) | Single teal Material 3 theme + brand color (no dark mode yet) |

## Conventions

- A widget never imports a repository, DAO, service, or `database.dart`. Views `ref.watch` their view model and call its command methods; shared widgets in `lib/ui/widgets/` are pure (no providers — they return user input and the screen acts on it).
- Drift entities are used directly as domain models — there is no mapper layer.
- Adding a feature: a screen + a `<Feature>ViewModel` under `lib/ui/<feature>/`; data access only through a repository (extend one or add to `lib/data/repositories/`). `test/` mirrors `lib/`.
- After any `@riverpod`/Drift change, run `dart run build_runner build --delete-conflicting-outputs`; the generated `*.g.dart` is committed.

Build, run, and local-test setup lives in [`docs/development.md`](../docs/development.md).

## Promotion rule

These files are the living truth home — they describe what the system does
*now*. When a change alters a capability's behavior, hand-edit the matching
`architecture/<capability>.md` in the same PR that ships the code, so the edit
is reviewed with the diff rather than applied as a separate post-merge step.

## History and rationale

Decision history and rationale live in [`planning/`](../planning/README.md); these docs describe the present state of the system.

# Habbits

A local-first, cross-platform habit tracker. Your data lives on your device —
no account, no server, no paywall. Habits are fully editable and hard-deletable
("okay, gone"), and exportable. Open source.

## Status

MVP in progress. This slice ships the core loop: create / rename / delete habits,
check off today, and see your current streak — all persisted locally via SQLite.

## Stack

Flutter · Drift (SQLite) · Riverpod. Pure-Dart domain layer for streak logic.

## Develop

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # after schema/provider changes
flutter test            # unit + widget tests
flutter run             # on a simulator/emulator
```

See `docs/superpowers/specs/2026-06-13-habbits-mobile-local-first-design.md` for the design.

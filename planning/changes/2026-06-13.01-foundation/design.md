---
summary: Initial local-first core loop.
---


# Habbits — mobile, local-first MVP

This is the constitution for Habbits after its pivot from a web-first Go+Postgres
backend project to a **cross-platform, local-first mobile app with no backend**.
It distills the surviving product thesis, rules, and competitive research from the
archived BMad-era docs (`docs/bmad-legacy/`) and folds in the 2026 deep-research
pass (`competitive landscape`, `UX/retention`, `local-first tech`, `positioning`).
Feature specs and plans reference this document by section.

## 1. Identity & thesis

Habbits is a habit tracker that is **local-first, offline, no-account, no-paywall,
and open source**, on **iOS and Android from one codebase**.

The product thesis is unchanged from the original brief and is *more* coherent
without a backend: **your data lives on your device; habits are fully mutable and
hard-deletable ("okay, gone"); you can export everything at any time.** No vendor
lock-in, no cloud you must trust, no fundamentals behind a paywall.

Dual purpose: (1) the author's daily-driver tracker (the five real habits:
exercises, medicine, workout, reading, meditation), and (2) a **portfolio-quality**
open-source artifact.

**Positioning (the niche the research found unclaimed):** Loop Habit Tracker's
data-ownership ethos — open source, offline, no network permission — but
**cross-platform** and with a **first-class heatmap**. Loop is Android-only;
HabitKit is cross-platform but paywalled (subscription + lifetime). Nobody owns the
intersection of *cross-platform + local-first + genuine data-ownership + no paywall*.

## 2. Locked decisions (stack)

- **Flutter / Dart**, 2026 stable (Impeller renderer). Chosen over React Native +
  Expo because: home-screen widgets work on **both** platforms (Expo's widget
  library is iOS-only), Expo's own docs flag its local-first tooling as "still
  immature," Flutter is mature in 2026, and the closest commercial success in this
  exact niche (HabitKit) is Flutter.
- **Drift** (typed SQLite) for persistence. Relational storage fits check-off
  history, streak math, and heatmap aggregation; key-value stores (MMKV/Hive) do
  not. MMKV-class speed is unnecessary at this data scale.
- **Riverpod** for state management — testable, idiomatic, pairs cleanly with Drift.
- **flutter_local_notifications** for reminders (fully on-device, no push service).
- **file_picker** + **share_plus** + `csv`/`dart:convert` for export/import.
- **Testing:** pure-Dart unit tests (domain logic), widget tests, one
  `integration_test` for the critical flow.

## 3. Product rules

Carried from the original spec, with all timezone/account machinery removed
(single device, single user, OS-provided local time):

- **Day** = the device's local calendar date. No stored timezone field. Streak
  adjacency is computed on calendar dates (not UTC offsets), so DST transitions do
  not corrupt it.
- **Streak** = count of consecutive calendar days — ending today (or yesterday, if
  today is not yet checked) — that have a completion. A gap resets it to 0.
  **Computed from `completions`, never stored.**
- **Completion %** = rolling 30-day window: completed days ÷ min(30, days since
  `created_at`). Excludes today when not yet checked.
- **Check-off** = boolean toggle for **any** date (retroactive editing is in MVP).
  Idempotent via a unique constraint on `(habit_id, local_date)`.
- **Delete** = hard delete of the habit and all its completions (FK cascade).
  Single confirmation, copy states it is permanent. No undo, no tombstone.
- **Edit** = rename, color, reminder time. Cadence is daily and not editable in MVP.
- **Streaks are forgiving.** A broken streak renders the truth (0) with **no
  punitive messaging** — no shame toast, modal, or notification. (Research: streaks
  boost short-term retention but harm long-term adherence via anxiety and outsourced
  motivation; forgiving design is the mitigation.)

## 4. Data model (on-device SQLite via Drift)

Two tables. No `users`, `sessions`, or `timezone` — the pivot deleted three of the
original four tables.

**`habits`**

| column | type | notes |
|---|---|---|
| `id` | INTEGER PK (autoinc) | |
| `name` | TEXT | renameable |
| `color` | INTEGER | ARGB, drives the heatmap |
| `reminder_time` | TEXT? | nullable `HH:mm`; null = no reminder |
| `sort_order` | INTEGER | manual list ordering |
| `created_at` | DATETIME | 30-day-% denominator |

**`completions`**

| column | type | notes |
|---|---|---|
| `id` | INTEGER PK (autoinc) | |
| `habit_id` | INTEGER FK → `habits.id` | **ON DELETE CASCADE** |
| `local_date` | TEXT (`YYYY-MM-DD`) | device-local calendar date |
| `created_at` | DATETIME | audit |
| | | **UNIQUE(`habit_id`, `local_date`)** |

Hard delete is real: `DELETE FROM habits WHERE id=?` and the cascade removes
completions. No soft-delete column.

## 5. Architecture (layers)

Conventional Flutter layering; the **domain layer is pure Dart** (no Flutter, no
Drift imports) so the load-bearing correctness logic — streak math — is unit-testable
in isolation.

```
lib/
├── main.dart                 # entry, ProviderScope, theme
├── data/
│   ├── database.dart         # Drift DB + connection
│   ├── tables.dart           # Habit, Completion schemas
│   └── habit_dao.dart        # CRUD, toggle completion, range fetch
├── domain/                   # PURE Dart — no framework deps
│   ├── models.dart           # Habit, Completion value types
│   ├── streak.dart           # current streak from a completion set
│   ├── completion_stats.dart # 30-day % computation
│   └── heatmap.dart          # date→state bucketing for the grid
├── services/
│   ├── notifications.dart    # schedule / cancel local reminders
│   └── backup.dart           # CSV/JSON export + import (+ validation)
├── state/                    # Riverpod providers (UI ↔ data/domain bridge)
│   ├── habit_list_provider.dart
│   └── habit_detail_provider.dart
└── ui/
    ├── habit_list/           # home: list + today's checkbox + streak
    ├── habit_detail/         # heatmap, history, edit/delete, reminder
    ├── habit_edit/           # create / rename form
    └── settings/             # export / import / about / license
```

**Data flow:** UI → Riverpod provider → `HabitDao` (Drift) for reads/writes.
Computed values (streak, %, heatmap buckets) come from pure domain functions fed by
completion rows. Nothing is denormalized — derived values recompute for free after a
retroactive edit.

## 6. MVP scope

**Core (always in):** create / rename / hard-delete habits; daily boolean check-off;
current streak per habit.

**Additions confirmed in MVP:**

- **GitHub-style heatmap** per habit — the category's signature visual and the main
  at-a-glance differentiator.
- **Retroactive editing** — tap any day in the heatmap to toggle it. Streak and %
  recompute from history.
- **30-day completion %** per habit.
- **CSV + JSON export & import** — backup, device migration, and the literal proof of
  the data-ownership thesis. Round-trip must reproduce identical state.
- **Local reminders** — optional per-habit reminder time via on-device
  notifications.

**Post-MVP, in priority order:**

1. **Home-screen widget** (iOS + Android) — strong differentiator and retention
   driver; partly why Flutter was chosen. Fast-follow #1.
2. Quantity-based habits (counts, durations) alongside boolean.
3. Flexible cadence (weekly, N×/week, custom) — changes streak math.
4. Best-streak metric per habit.
5. Cloud sync / backup (would reintroduce a backend or platform cloud; deliberately
   deferred to preserve the no-backend MVP).

**Never (out of vision):** gamification (XP, avatars, currency-streaks), social
feeds, AI suggestions, ads, any paywall on core functionality.

## 7. Quality bars

- **Correctness (load-bearing):** table-driven unit tests for streak math (gaps,
  today-checked-vs-not, month boundaries, DST-day transitions) and 30-day %
  (creation-day edge, capped denominator). Most habit-tracker bugs live here.
- **Idempotency:** double-toggling the same day nets to the original state; enforced
  by the unique constraint.
- **Hard-delete integrity:** deleting a habit removes all its completions (cascade
  verified by test).
- **Data-ownership round-trip:** export → wipe → import reproduces identical habits
  and history (test). Invalid/corrupt import is rejected with a clear error, never a
  partial write.
- **Reliability:** all writes go through Drift transactions.
- **Accessibility (pragmatic floor):** ≥48dp tap targets, semantic labels on
  icon-only buttons, sufficient contrast. No formal WCAG audit.

Bars dropped by the pivot (no longer applicable): API latency, FCP/TTI/bundle-size,
argon2id/cookie/CSRF security, TLS, request-ID propagation, server observability.

## 8. Critical flow (the `integration_test` target)

> open app → create habit → check off today → see streak = 1 → kill & relaunch →
> state persists (from SQLite)

If this fails on a real device/emulator, the MVP is not done.

## 9. Positioning & distribution

- **Open source + free.** Public repository, free on both stores. This is the
  strongest portfolio artifact and the purest expression of the no-paywall /
  data-ownership thesis (Loop's positioning, extended cross-platform).
- **Discovery:** App Store Optimization is the dominant channel for indie habit apps
  (~98% of HabitKit's installs came from store search). A clear name, screenshots
  that lead with the heatmap, and keyword-aware store copy matter more than any other
  growth lever.
- **No monetization in MVP.** If a paid tier is ever added, follow the HabitKit
  pattern (subscription + one-time lifetime) and keep core features free — but this
  is explicitly out of scope and out of the thesis for the foreseeable future.

## 10. Out of scope (MVP)

Accounts / auth, any backend or server, cloud sync, multi-device, home-screen widgets
(fast-follow), quantity-based habits, flexible cadence, best-streak metric, social,
gamification, AI, ads, paywalls.

## 11. Provenance

- **Distilled from (archived, frozen):** `docs/bmad-legacy/product-brief-habbits.md`,
  `…-distillate.md`, `prd.md` — product thesis, the five-habits use case, product
  rules (streak/%/delete), competitive intel. Their *technical* content (Go, Postgres,
  auth, Fly.io, web) is abandoned.
- **Deleted as obsolete:** the Go backend code, the foundation spec, the
  day-1-deploy spec + plan, `bmad-legacy/architecture.md`, and the
  BMad→Superpowers migration docs — all described the abandoned backend approach.
- **2026 deep research** informed: pulling the heatmap and export into MVP, forgiving
  streak design, the Flutter-over-Expo stack call (widgets), and open-source
  positioning.

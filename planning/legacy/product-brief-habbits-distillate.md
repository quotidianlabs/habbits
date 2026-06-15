---
title: "Product Brief Distillate: Habbits"
type: llm-distillate
source: "product-brief-habbits.md"
created: "2026-05-05"
purpose: "Token-efficient context for downstream PRD creation"
---

# Habbits — Brief Distillate

## Project Identity

- Codename / directory: `habbits` (deliberate spelling with two `b`s — never confirmed if intentional or typo; treat as project codename, "habit" remains the noun in copy).
- Dual purpose: (1) author's daily habit tracker replacing coach.me; (2) full-cycle development learning vehicle.
- Time horizon: 1–3 weeks of solo evening/weekend work.
- Primary user is the author. Secondary users are post-MVP (friends/family, future self-host audience) — not designed for at v1.

## Five Tracked Habits (Author's Real Use Case)

Concrete daily habits that drive product-shape decisions:

- Exercises
- Medicine consumption
- Workout
- Reading
- Meditation

Implication for v1: a hardcoded set isn't enough — habits must be user-created and freely deletable, since "workout" semantics differ per person. But cadence is daily for all five → daily-only is acceptable in v1.

## Requirements Hints (Beyond Executive Summary)

- Streaks must be visible (non-negotiable; primary motivator).
- Some statistics / analysis required — narrowed in v1 to: current streak + completion percentage.
- Habits must be deletable. The founding gripe with coach.me. This is the headline behavior.
- Web first, mobile second (within same RN + Expo codebase).
- "Just get working" across all learning slices — no specific slice to deepen vs. just-implement.

## Technical Constraints & Preferences

### Locked decisions (in brief)

- **Backend:** Go, `net/http` + `chi`, Postgres, `goose` migrations, `database/sql` + thin repo layer.
- **Frontend:** React Native + Expo + `react-native-web`, TypeScript.
- **Auth:** server-side sessions, HttpOnly + Secure + SameSite=Lax cookies, `argon2id` password hashing, CSRF on state-changing routes.
- **Architecture:** single Go binary serves both `/api/...` and the built SPA. Same-origin → no CORS.
- **Hosting:** Fly.io app + Fly Postgres. Single `FLY_API_TOKEN` secret in GHA.
- **CI/CD:** GitHub Actions. PR: `go test`, frontend units, Playwright smoke. Merge to `main`: `flyctl deploy`.
- **Testing:** Go `httptest` (handlers + integration in one tier), Jest/RTL frontend units, one Playwright happy-path e2e.
- **Observability:** `slog` structured logs, request IDs, panic-recovery middleware. No metrics in v1.

### Deferred to PRD

- `sqlc` adoption (deferred unless schema stops moving).
- Best-streak metric (currently optional in MVP).
- Specific email validation / signup flow detail.
- CSRF library / token strategy specifics.
- Test database seeding strategy for Playwright (likely a `/test/seed` endpoint behind a build tag).

## Product Rules (Locked, Not Implementation Detail)

- A "day" = user's local calendar day, computed from a `timezone` field on the user record.
- Streak = consecutive prior days (incl. today) with ≥1 check-off, in user TZ. Missed day → reset to 0.
- Completion % = rolling 30-day window: completed-days ÷ days-since-creation (capped at 30). Excludes today if not yet checked.
- Deletion = hard delete of habit + check-offs. No undo, no tombstone.
- Edit = rename only in v1. Cadence is daily and not editable.
- Check-off = today only in v1. No retroactive editing.

## Data Model (Sketch, Locked in PRD)

- `User`: id, email, password_hash, timezone, created_at.
- `Habit`: id, user_id, name, created_at, deleted_at (decision: hard vs soft delete to be locked in PRD; brief favors hard delete).
- `Completion`: habit_id, user_id, local_date, created_at. Unique on `(habit_id, local_date)`.
- `Session`: id, user_id, expires_at. Opaque cookie value.

## Rejected Ideas (Do Not Re-Propose)

- **Password reset in MVP** — rejected. Hides email infra (SMTP/SES/Resend, templates, tokens, rate limiting, ~1–3 days). Author can self-recover via direct DB write if locked out.
- **JWT auth** — rejected in favor of server-side sessions. Simpler for web-first MVP, no token-refresh complexity.
- **Separate origins for API and SPA** — rejected. Same-origin via single Go binary eliminates CORS.
- **OIDC for CI deploy** — rejected. Single `FLY_API_TOKEN` secret is sufficient.
- **`sqlc` for v1 DB layer** — rejected. ~3 tables; `database/sql` + thin repo is faster.
- **Plain React + Vite for v1 web** — rejected as default (see kill-criteria fallback below). RN+Expo+RNW from day one is the bet, since mobile parity is a stated post-MVP goal.
- **SQLite for v1** — rejected. Postgres is a named learning slice.
- **Single-user mode (no auth) for v1** — rejected as default. Auth is a named learning slice.
- **Reminders / push notifications** — rejected for v1. APNs/FCM/Expo Push complexity. Backlog priority high.
- **Non-daily cadence** (weekly, "3x/week", custom) — rejected for v1. Complicates streak math and UX.
- **Quantity-based completion** (sets, minutes, count) — rejected for v1. Boolean only.
- **Heatmap / GitHub-style contribution viz** — rejected for v1. UX pattern to borrow post-MVP.
- **Time-of-day / weekday analytics** — rejected for v1.
- **Gamification, social, AI insights, Apple Health / Google Fit** — explicitly rejected for v1 by user.
- **CSV / JSON data export in MVP** — currently in backlog. Reviewer flagged this as a half-day add that would convert "data ownership" from principle to demo. *Not yet decided whether to pull into MVP.*

## Kill-Criteria Fallbacks (Pre-Authorized Scope Cuts)

If hit during the build, the brief authorizes:

- RN+Expo+RNW setup costing >2 days in week 1 → drop to plain React + Vite for web; accept divergent mobile codebase later.
- Auth not working by end of week 2 → drop to single-user mode with hardcoded account.
- Day 7 dogfood target slipping >3 days → cut a feature, do not extend timeline.
- Any backlog item that "feels almost free" mid-sprint → blocked from landing until ≥7 consecutive dogfooding days.

## Recommended Build Order (Pragmatic Sequence)

1. Day 1: hello-world Go binary deployed to Fly.io with domain + TLS via GHA. Kills the deploy yak shave first.
2. Schema + repo layer (Postgres + goose migrations).
3. JSON API behind bearer-token middleware (skip real auth initially): `GET /habits`, `POST /habits/:id/checkoffs`, `DELETE /habits/:id`.
4. Minimal RN+Expo+RNW web UI (list, today's checkbox, streak, delete). Deploy. **Dogfood here, end of week 1.**
5. Replace bearer-token with real signup/login (cookie sessions, CSRF, argon2id).
6. Wire one Playwright smoke into GHA.
7. Week 2-3 stretch (pick one, not all): best-streak metric, edit-habit UI, mobile parity via Expo Go, password reset.

## Critical E2E Flow (Single Required Path)

```
sign up → create habit → check off today → see streak = 1 → reload → state persists
```

This is the e2e test target. If this flow doesn't pass on the deployed environment, the MVP is not done.

## Day 7 Dogfood Target (Concrete Definition of Working)

Author opens the deployed URL on their phone, checks off "medicine" for today, sees the streak go to 1, reloads, the state persists.

## Hidden Scope Items Flagged by Reviewers (Watch For)

- **Auth**: signup/login alone hides cookie flag tuning, password hashing tuning, session refresh, CSRF token strategy. ~1-2 days realistic, not hours.
- **CI/CD deploy**: Fly.io provisioning, Postgres init, secrets, container build, migration step in deploy. ~0.5-1 day realistic.
- **react-native-web**: Expo Router web quirks, font loading, Reanimated/gesture-handler web shims, StyleSheet (no CSS), keyboard/focus parity. Pin Expo SDK exact version; avoid Reanimated/Gesture Handler on web in v1.
- **Streak math + DST**: write a table-driven test crossing DST boundaries early. Most common habit-tracker bug class.
- **Migration tooling bikeshed**: pre-decided as `goose`. Do not revisit.
- **Cookie auth across origins**: pre-eliminated by same-origin architecture. If that constraint relaxes, CSRF + SameSite tuning resurfaces.
- **Playwright in CI**: needs ephemeral DB or `/test/seed` endpoint behind build tag, deterministic dates for streak assertions.

## Competitive Intelligence (From Web Research, 2026)

### Tracker landscape

- **coach.me** — author's prior tool. Cannot delete habits. The founding gripe.
- **Habitica** — RPG gamification, dated UI, social bolted on. Out of scope flavor.
- **Streaks (iOS)** — polished, Apple Health integrated, Apple-only, hard 24-habit cap.
- **Loop Habit Tracker** — Android-only, OSS, strong CSV/SQLite export, no cloud sync.
- **HabitKit** — GitHub-style heatmaps as primary visual; weak reminders.
- **Way of Life, Done** — also commonly cited.

### Industry-wide pain points (validating the design principles)

- Habits not editable / deletable after creation.
- Aggressive paywalls on basics (adding habits, exporting data).
- No data export, no self-hosting.
- Notifications misfiring (post-completion alarms, late reminders).
- Statistics shallow beyond a streak count.

### UX patterns worth borrowing post-MVP

- GitHub-style contribution heatmap per habit.
- Apple-style closing rings + streak counter combo.
- Cue-routine-reward framing tied to time/location cues.

### 2026 stack consensus

- **Hybrid frontend**: RN + Expo + react-native-web is the pragmatic web+iOS+Android-from-one-codebase recommendation. Flutter is bigger market share but Dart is a second language and Flutter Web is weaker. KMP requires writing 3 UIs (wrong fit for solo). Capacitor only if web-primary.
- **Go web stack**: `net/http` + `chi` is the new idiomatic default since Go 1.22+ routing improvements. Gin still has share for batteries-included. Echo is the middle.

## Open Questions (Surfaced, Not Resolved)

- **Project name spelling** — `habbits` vs `habits`. Treated as deliberate codename. Confirm at PRD time if user-facing copy should use `habits`.
- **CSV/JSON export pulled into MVP?** Half-day work, makes data-ownership principle real. Currently backlog. Author has not decided.
- **Apple Health / Google Fit integration priority** — confirmed out of v1; relative position in backlog unclear.
- **Coach.me data import** — never discussed. Without it, author starts from zero streaks, which is a documented behavioral barrier even for self-adoption. Worth a backlog placeholder.
- **Best-streak metric in v1** — currently optional.
- **Public OSS positioning** — opportunity reviewer flagged this as high-leverage if author wants a portfolio artifact. Not committed.
- **ADRs as a build-time artifact** — opportunity reviewer flagged. Low cost, high portfolio value. Not committed.
- **Build-in-public log / blog series** — opportunity reviewer flagged. Not committed.

## Reviewer-Surfaced Strengths to Carry Forward

- The "okay, gone" deletion thesis is the strongest line in the brief — lean into it in README copy and any screenshot framing.
- Author-is-user feedback loop ("decisions in minutes, not quarters") is unique and underemphasized — could become a measurable success metric ("days from idea to merged change").
- Single-codebase web+mobile via Expo+RNW is the most interesting architectural choice — structuring v1 web as a real RN+Expo project (not a stub) makes mobile a packaging exercise, not a rewrite.
- Same-origin Go binary serving API + SPA eliminates a whole class of pain (CORS, separate hosting, secrets duplication).

## Inputs to Next Phase (PRD)

When generating the PRD, key things to lock that the brief left implicit:

- Hard vs soft delete final call (brief favors hard).
- Specific migration tooling configuration (goose embed or filesystem).
- CSRF token strategy (double-submit cookie, synchronizer token, or framework-provided).
- Frontend state management (TanStack Query is a likely default; not yet decided).
- Form validation approach (Zod, manual, or react-hook-form).
- Test DB strategy (ephemeral Postgres in GHA service container, or SQLite in tests despite Postgres in prod).
- Domain + TLS cert provisioning specifics on Fly.
- Local dev story (docker-compose for Postgres, or `fly proxy`).

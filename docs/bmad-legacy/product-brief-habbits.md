---
title: "Product Brief: Habbits"
status: "complete"
created: "2026-05-05"
updated: "2026-05-05"
inputs:
  - "User discovery conversation (2026-05-05)"
  - "Web research: 2026 habit-tracker landscape and hybrid frontend stack"
  - "Review panel: skeptic, opportunity, and solo-build realism lenses"
---

# Product Brief: Habbits

## Executive Summary

**Habbits** is a personal habit tracker that respects the user's data — habits are mutable, deletable, and exportable, by principle. It is being built as a dual-purpose project: a daily-driver tool replacing coach.me for the author's own habit tracking (exercises, medicine, workout, reading, meditation), and a deliberate full-cycle development exercise across a Go backend, a React Native + Expo + react-native-web frontend, and a complete CI/CD and testing pipeline.

Existing habit trackers — coach.me, Habitica, Streaks, HabitKit, Loop — share a recurring set of frustrations: locked-after-creation habits that can't be edited or deleted, paywalled basics, no data export, and shallow analytics beyond a streak count. Industry-wide user feedback confirms these are not niche complaints. Habbits inverts the default: **your habits, your data, your right to change your mind.**

The MVP is intentionally narrow — five daily checkbox habits, streaks, and completion percentages, on the web — sized to ship in 1–3 weeks. Mobile, reminders, social, gamification, AI insights, and health integrations are explicitly out of scope and live in the backlog.

## The Problem

The author has used coach.me as a daily habit tracker and hit a wall most users hit: **you can't delete a habit you no longer care about.** The list grows stale, motivation decays, the tool becomes a graveyard of abandoned intentions. Industry research confirms the pattern is not unique to coach.me:

- Habits become locked after creation — frequency, name, color cannot be changed.
- Deletion is restricted, hidden, or paywalled.
- Data export (CSV / JSON) is missing, locking users into vendor cloud.
- Analytics rarely go beyond a single streak number — no weekday patterns, no completion ratios.
- Free tiers gate fundamentals; basic widgets desync from app data.

For someone trying to track real-life habits — taking medicine, working out, reading, meditating — the tool is supposed to reduce friction, not introduce it. When the tracker itself becomes an obstacle, the habit dies before the streak does.

Separately, the author wants to ship a complete, end-to-end software project — backend, database, auth, web frontend, mobile, CI/CD, automated testing — to exercise full-cycle development as a single coherent piece. Existing personal habit trackers don't satisfy either need.

## The Solution

A clean, multi-user habit tracker focused on the basics done well:

- **Daily checkbox habits** — boolean completion, no quantity tracking in v1.
- **Streaks and completion percentage** — the two metrics that matter for early signal.
- **Fully mutable habits** — rename, edit, delete at any time, no friction.
- **Account-based sync** across devices, with a Go REST API and Postgres backing store.
- **Web-first UI** in v1, with mobile (iOS + Android) following from the same React Native + Expo codebase via `react-native-web`.
- **Auth** — signup, login, session/token-based authentication.

The product surface is small on purpose. Every line of MVP scope is something the author will use within the first week of dogfooding.

## What Makes This Different

This is, candidly, a personal pet project — not a market entry. The differentiation matters mainly as a design principle and a reason to build at all rather than adopt an existing app:

- **Data ownership as a default**, not a paid feature.
- **No lock-in**: habits are user-controlled records, not platform property.
- **Minimum viable surface** — no gamification, no avatars, no streaks-as-currency.
- **Built for one person to actually use** — every feature passes the test "do I use this for my five habits?"

The unfair advantage is execution context: the author is the user, the designer, and the builder. Decisions can be made in minutes, not quarters.

## Who This Serves

**Primary user (v1):** the author — tracking five daily habits (exercises, medicine, workout, reading, meditation), wanting visible streaks, expecting the tool to never get in the way.

**Secondary users (post-MVP):** people who hit the same wall with existing trackers — frustration with rigidity, lock-in, paywalls — and want a no-nonsense, web-and-mobile, multi-device tracker with their data under their control.

**Aha moment:** the user creates a habit, decides a week later it doesn't fit their life, deletes it without negotiation, and the app responds with "okay, gone." That single interaction is the product's thesis.

## Success Criteria

**Personal-use success (primary):**

- All five core habits (exercises, medicine, workout, reading, meditation) tracked daily.
- Streaks visible and accurate.
- Habbits replaces coach.me as the author's daily tracker.

**Day 7 dogfood target (concrete):** the author opens the deployed URL on their phone, checks off "medicine" for today, sees the streak go to 1, reloads, the state persists. If this isn't true by end of week 1, scope must be cut, not extended.

**Critical end-to-end flow** (the one path that must work and is the e2e test target):
> sign up → create habit → check off today → see streak = 1 → reload → state persists.

**Learning success (parallel track):**

A working, end-to-end implementation across all of the following — depth at the "competent and idiomatic" level, not specialization. Each slice has a single concrete artifact that proves it:

- **Go API design** (`net/http` + `chi`): a versioned REST API with a `recoverer`, `request-id`, and `auth` middleware chain.
- **Postgres schema + migrations**: `goose` migrations checked into the repo; schema rebuildable from zero.
- **Authentication**: signup + login with HttpOnly cookie sessions, password hashed with `bcrypt`/`argon2id`. Password reset is *not* in MVP — moved to backlog.
- **Cross-platform frontend** via React Native + Expo + `react-native-web`: the v1 web app is a real RN+Expo project, not a stub, so mobile becomes a packaging exercise rather than a rewrite.
- **CI/CD pipeline** (GitHub Actions): on every PR, `go test` + frontend unit tests + Playwright smoke run; on merge to `main`, `flyctl deploy`.
- **Automated testing**: Go `httptest`-driven handler tests against a real test database; a single Playwright happy-path e2e.
- **Basic observability**: `slog` structured logs with request IDs and panic recovery; metrics deferred unless trivial.

## Scope

### Product Rules (locked in v1, not implementation details)

- **A "day"** is the user's local calendar day, computed from a timezone stored on the user record.
- **Streak** = consecutive prior days (up to and including today) with at least one check-off, in the user's timezone. A missed day resets the streak to zero.
- **Completion %** = rolling 30-day window: completed-days ÷ days-since-habit-created (capped at 30). Excludes today if not yet checked.
- **Deletion** = hard delete of the habit and its check-offs. No undo, no tombstone. The product's headline behavior is "okay, gone."
- **Editing** = rename only in v1. Frequency / cadence is daily and not editable.

### Data Model (sketch — locked in PRD)

- **User**: `id`, `email`, `password_hash`, `timezone`, `created_at`.
- **Habit**: `id`, `user_id`, `name`, `created_at`, `deleted_at` (or hard delete).
- **Completion**: `habit_id`, `user_id`, `local_date` (the user-TZ calendar date), `created_at`. Unique on `(habit_id, local_date)`.
- **Session**: `id`, `user_id`, `expires_at` (server-side session, opaque cookie).

### In scope (MVP, ~1–3 weeks)

- Multi-user accounts: signup, login, logout. **Password reset is deferred to backlog.**
- Create, rename, delete habits.
- Daily check-off (boolean, today only in v1 — no retroactive editing).
- Current streak per habit (best streak optional).
- Completion percentage per habit (rolling 30-day window).
- Web app (responsive), built as a real React Native + Expo + `react-native-web` project.
- Go API + Postgres, served from a single binary.
- **Same-origin architecture**: the Go binary serves both the API (`/api/...`) and the built SPA. No CORS, no separate origins.
- Deployed to **Fly.io** with managed Postgres; `flyctl deploy` triggered from GitHub Actions on merge to `main`.
- Automated tests: Go `httptest` handler+integration tests against a real test DB; one Playwright happy-path e2e covering the critical flow.

### Explicitly out of scope (deferred to backlog)

- **Password reset** (requires email infra — SMTP, templates, token storage, rate limiting).
- Mobile apps (iOS, Android) — post-MVP, same RN + Expo codebase.
- Reminders / push notifications (APNs, FCM, Expo Push).
- Non-daily cadence (weekly, custom schedules).
- Quantity-based completion (counts, durations, sets).
- Retroactive check-offs (only "today" in v1).
- Heatmap / GitHub-style contribution visualization.
- Time-of-day / weekday analytics.
- Social features, accountability buddies, shared habits.
- Gamification (XP, avatars, rewards).
- AI insights and recommendations.
- Apple Health / Google Fit integration.
- CSV / JSON data export (high-priority backlog given the data-ownership principle).

### Recommended Build Order (kills the biggest yak shaves first)

1. **Day 1**: deploy a hello-world Go binary to Fly.io with a domain + TLS via GitHub Actions. This kills the deploy yak shave before any feature code.
2. Schema + repo layer for habits and check-offs in Postgres; `goose` migrations.
3. JSON API behind a single bearer-token middleware (no real auth yet): `GET /habits` (with computed streak + 30-day %), `POST /habits/:id/checkoffs`, `DELETE /habits/:id`.
4. Minimal RN+Expo+RNW web UI: list of habits, today's checkbox, streak number, delete button. Deploy. **Begin dogfooding here — end of week 1.**
5. Replace bearer-token middleware with real signup/login (HttpOnly cookie sessions, CSRF protection, `argon2id` password hashing).
6. One Playwright smoke test wired into GHA.
7. Week 2-3 stretch: best-streak metric, edit-habit UI, Apple Health integration, mobile parity (run the existing RN+Expo project on iOS/Android via Expo Go) — pick one, not all.

### Kill Criteria (when to abort or downgrade)

- If RN+Expo+react-native-web setup costs more than 2 days of yak-shaving in week 1, drop to plain React + Vite for web and accept a divergent codebase for mobile.
- If auth (signup + login + cookie sessions) is not working by end of week 2, drop to single-user mode with a hardcoded account and ship.
- If the Day 7 dogfood target slips by more than 3 days, cut a feature — not extend the timeline.
- If any single backlog item starts feeling "almost free" mid-sprint (export, heatmap, mobile, reminders), it does not land before 7 consecutive days of dogfooding.

## Vision

Habbits, if it succeeds for its first user, becomes the author's permanent habit tracker — the one that doesn't fight back. Beyond that, the natural growth path is:

1. **Mobile parity** via the existing RN + Expo codebase.
2. **Reminders** to close the open loop on adherence.
3. **Richer analytics** — heatmaps, weekday patterns, completion trends.
4. **Flexible cadences** — weekly, custom, target-based.
5. **Data export and self-hosting** — making the data-ownership principle real.

The 2–3 year shape is a small, opinionated, no-bullshit habit tracker that an individual can run for themselves or a few friends without trusting a vendor. It will not become Habitica.

## Technical Approach (Brief)

- **Backend:** Go, `net/http` + `chi` routing, Postgres, `goose` for migrations. `database/sql` with a thin repository layer for v1; `sqlc` deferred unless schema stops moving.
- **Frontend:** React Native + Expo + `react-native-web`, TypeScript. Single codebase targets web in v1, mobile post-MVP.
- **Auth:** server-side sessions in HttpOnly, Secure, SameSite=Lax cookies. Password hashing via `argon2id`. CSRF protection on state-changing routes.
- **Architecture:** single Go binary serves both the JSON API (`/api/...`) and the built SPA. No CORS, no separate origins.
- **Hosting:** Fly.io for the app + Fly Postgres. Single `FLY_API_TOKEN` secret in GHA.
- **CI/CD:** GitHub Actions. PR: `go test`, frontend unit tests, Playwright smoke. Merge to `main`: `flyctl deploy`.
- **Testing:** Go `httptest` for handler + integration tests; Jest / RTL for frontend units; one Playwright happy-path e2e (the critical flow).
- **Observability:** `slog` structured logs with request IDs; panic-recovery middleware; metrics deferred unless trivial.

This brief is followed by a PRD that locks the remaining technical decisions.

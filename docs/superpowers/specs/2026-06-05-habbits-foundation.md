---
title: Habbits foundation spec
date: 2026-06-05
status: locked
type: foundation
---

# Habbits foundation

This spec is the constitution for the Habbits project. Future feature specs and implementation plans reference it by section (e.g., "per foundation §3, streak resets on missed day") rather than restating shared rules. Detailed FR/NFR text lives in `docs/bmad-legacy/prd.md` and is referenced, not duplicated.

## 1. Identity

Habbits is a personal habit tracker built on an inverted default: habits are user-owned, fully mutable, and hard-deletable by design — not as a paid feature. It serves a dual purpose: daily-driver tracker replacing coach.me (tracking exercises, medicine, workout, reading, meditation), and a deliberate full-cycle development exercise. v1 scope is five daily checkbox habits, two metrics (current streak + 30-day completion %), web only, single user (the author). Mobile is post-MVP from the same codebase. Time horizon: 1–3 weeks of solo work.

## 2. Locked decisions

**Backend:**
- Go, `net/http` + `chi`, Postgres, `goose` migrations. Thin repository layer over `database/sql` or `pgx` (driver decided in the relevant plan). `sqlc` deferred.

**Frontend:**
- React Native + Expo + `react-native-web`, TypeScript, TanStack Query for server state, Expo Router for client routing.

**Auth:**
- Server-side opaque-token cookie sessions. HttpOnly + Secure + SameSite=Lax. `argon2id`. CSRF on all state-changing routes.

**Architecture:**
- Single Go binary serves `/api/...` (JSON) and `/` (built SPA via `embed.FS`). Same-origin. No CORS.

**Hosting:**
- Fly.io app + Fly Postgres. Single `FLY_API_TOKEN` secret in GHA.

**CI/CD:**
- GitHub Actions. PR runs `go test`, frontend units, Playwright smoke. Merge to `main` runs `flyctl deploy`.

**Testing:**
- Go `httptest` for handlers + integration, Jest/RTL for frontend units, one Playwright happy-path e2e.

**Observability:**
- `slog` structured logs, request IDs, panic-recovery middleware. No metrics in v1.

## 3. Product rules

- **Day** = user's local calendar date, computed from a `timezone` field on the user record.
- **Streak** = consecutive prior local days (including today, if checked) with ≥1 check-off in user TZ. Missed day → reset to 0.
- **Completion %** = rolling 30-day window: completed-days ÷ days-since-creation (capped at 30). Excludes today when not yet checked. Day-0 boundary behavior (creation-day-only, no checks yet) is decided in the implementation plan that ships the metric.
- **Delete** = hard delete of habit + all check-offs. No undo, no tombstone.
- **Edit** = rename only in v1. Cadence is daily and not editable.
- **Check-off** = today only in v1. No retroactive editing.

## 4. Data model sketch

- `User`: `id`, `email`, `password_hash`, `timezone`, `created_at`.
- `Habit`: `id`, `user_id`, `name`, `created_at`. Hard delete (no `deleted_at`).
- `Completion`: `habit_id`, `user_id`, `local_date`, `created_at`. Unique on `(habit_id, local_date)`.
- `Session`: `id`, `user_id`, `expires_at`. Opaque token as cookie value.

Schema specifics (indexes, FK cascade behavior, column types) are decided per implementation plan.

## 5. Functional capabilities

### Account management

Email/password sign-up, sign-in, sign-out; session persistence across reloads and devices; timezone captured at signup; unique-email enforcement; irreversible password storage. See `docs/bmad-legacy/prd.md` FR1–FR8.

### Habit management

Create / rename / hard-delete with confirmation; per-user isolation; no restore mechanism. See FR9–FR15.

### Daily check-off

Today-only, idempotent per (habit, local-date); reflected in the UI without a full page reload. See FR16–FR20.

### Progress visibility

Computed streaks and 30-day completion % displayed per habit; no punishment messaging for broken streaks. See FR21–FR25.

### Cross-device access

Mobile-first portrait layout, ≥44pt tap targets, full keyboard navigability on desktop. See FR26–FR28.

### System behavior

Auth required on all CRUD; CSRF on state-changing routes; server-side per-resource authorization. See FR29–FR32.

## 6. Quality bars

CI gates: Go tests + the one Playwright happy-path e2e. Performance, accessibility, and Lighthouse targets are verified manually or via spot-check, not blocked in CI.

### Performance

FCP <2s, TTI <3.5s on mobile 4G; GET /habits median <100ms; check-off median <80ms; gzipped JS bundle ≤350KB. The 100ms target forbids N+1 — habit list must compute streaks and 30-day % in a single batched query. See `docs/bmad-legacy/prd.md` NFR1–NFR5.

### Security

`argon2id` with OWASP params; HttpOnly+Secure+SameSite=Lax cookies; CSRF on state changes; 30-day idle session expiry; log redaction of auth secrets; TLS-only; server-side authorization on every resource. See NFR6–NFR12.

### Reliability

No formal SLA; deploys ≤30s of in-flight unavailability; panic-recovery middleware required; multi-step writes execute in a single transaction. See NFR13–NFR15.

### Accessibility

Pragmatic floor: keyboard reachability + visible focus indicators, 4.5:1 contrast, semantic labels, VoiceOver smoke test of the critical flow. No formal WCAG audit. See NFR16–NFR19.

### Privacy

Collect only what's needed: email, password hash, timezone, habits, check-offs. Hard delete is real — no soft-delete tombstone. See NFR20–NFR21.

### Observability

Structured `slog` logs; unique request ID per HTTP request propagated through logs and returned as `X-Request-ID`; migration-driven reproducible schema; ≤5-command reproducible build. See NFR22–NFR25.

## 7. Cross-cutting concerns

1. **Timezone handling.** User TZ stored on `User` at signup; applied at every date computation — idempotency, streak math, completion %. Wrong handling here breaks all of §3.
2. **Per-resource authorization.** Every habit and completion access must verify `user_id = session.user_id`. Single bug here = cross-user data leak.
3. **Request-ID propagation.** Generated at ingress middleware, attached to context, logged on every line, returned as `X-Request-ID`, and included in panic-recovery logs.
4. **CSRF protection.** Applied to all POST/PUT/PATCH/DELETE routes. Token strategy (double-submit cookie vs synchronizer) decided in the auth plan.
5. **Transactional integrity.** Multi-step writes (habit delete cascading to completions; signup creating user + first session) execute in a single DB transaction.
6. **Same-origin asset serving.** Go binary routes `/api/*` to handlers; falls through to embedded SPA bundle with catch-all returning `index.html` for client routes. Ordering must not let API 404s serve `index.html`.
7. **Schema migration on deploy.** `goose` migrations run before the binary serves requests. Wired in via Fly release-command.
8. **Log redaction.** Centralized redact list for passwords, session tokens, CSRF tokens; applied at the logging middleware boundary, never per-handler.
9. **Build embedding.** Frontend built in GHA, output embedded into the Go binary via `go:embed`. The CI image needs Node.

## 8. Out of scope

- Password reset (deferred — requires email infra).
- Mobile apps (post-MVP via same RN+Expo codebase).
- Reminders / push notifications.
- Non-daily cadence; quantity-based completion; retroactive check-offs.
- Heatmap, weekday analytics, time-of-day stats.
- Social, gamification, AI insights, Apple Health / Google Fit.
- CSV/JSON data export (high-priority post-MVP — see brief).
- JWT auth, separate origins, OIDC for CI deploy, `sqlc`, SQLite, single-user mode.

## 9. Kill criteria

- RN+Expo+RNW setup costing >2 days → drop to plain React + Vite for web; accept divergent mobile codebase later.
- Auth not working by end of week 2 → drop to single-user mode with hardcoded account.
- Day-7 dogfood target slipping >3 days → cut a feature; do not extend the timeline.
- Any backlog item that "feels almost free" mid-sprint → blocked from landing until ≥7 consecutive dogfooding days.

## 10. Build order

Build order kills the largest yak shaves first. The first implementation plan implements step 1.

1. Day 1: hello-world Go binary deployed to Fly.io with domain + TLS via GHA.
2. Schema + repo layer (Postgres + goose migrations).
3. JSON API behind bearer-token middleware (temporary scaffolding; replaced by real auth in step 5): `GET /habits`, `POST /habits/:id/checkoffs`, `DELETE /habits/:id`.
4. Minimal RN+Expo+RNW web UI: list, today's checkbox, streak, delete. Deploy. **Dogfood here, end of week 1.**
5. Replace bearer-token with real signup/login (cookie sessions, CSRF, argon2id).
6. Wire one Playwright smoke into GHA.
7. Week 2–3 stretch: pick one of best-streak, edit UI, mobile parity, password reset.

---
stepsCompleted:
  - step-01-init
  - step-02-context
inputDocuments:
  - /Users/kevinsmith/src/habbits/docs/product-brief-habbits.md
  - /Users/kevinsmith/src/habbits/docs/product-brief-habbits-distillate.md
  - /Users/kevinsmith/src/habbits/docs/prd.md
workflowType: architecture
project_name: Habbits
user_name: Kevin
date: 2026-05-12
documentCounts:
  prd: 1
  ux: 0
  research: 0
  projectDocs: 0
  projectContext: 0
---

# Architecture Decision Document — Habbits

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements (32 FRs across 6 capability areas):**

- *Account Management (FR1–FR8):* sign-up, sign-in, sign-out, session persistence, multi-device, timezone capture, irreversible password storage, unique-email enforcement. Implies a `User` entity, a `Session` entity, and a password-hashing layer at the auth boundary.
- *Habit Management (FR9–FR15):* CRUD with rename-only edits, hard delete with confirmation, per-user isolation. Implies a `Habit` entity owned by a `User`, with cascading delete to `Completion`.
- *Daily Check-Off (FR16–FR20):* user-local-day check-off, server-side TZ semantics, per-day idempotency, today-only enforcement, optimistic client update. Implies a `Completion` entity with a uniqueness constraint on `(habit_id, local_date)` and TZ-aware date computation at the API boundary.
- *Progress Visibility (FR21–FR25):* streaks and 30-day completion % computed at query time (not stored), broken-streak honesty, no automated punishment messaging. Implies a read path that performs date-bucket aggregation across `Completion` per habit.
- *Cross-Device Access (FR26–FR28):* mobile-first responsive UI, ≥44pt tap targets, keyboard navigability. Frontend concern; no backend implication beyond stateless session reuse.
- *System Behavior (FR29–FR32):* authentication middleware on protected routes, CSRF on state-changing routes, server-side authorization on every resource access, client-side error boundary. Implies a clear middleware chain (recoverer → request-id → auth → CSRF → handler) and per-route ownership checks.

**Non-Functional Requirements (25 NFRs across 6 categories):**

- *Performance (NFR1–NFR5):* FCP <2s, TTI <3.5s, GET /habits median <100ms, POST /checkoffs median <80ms, gzipped JS <350KB. The 100ms habit-list target forbids N+1 queries; streaks and 30-day % must be computed in a single query per request, or via a single batched query producing all habits with their aggregates.
- *Security (NFR6–NFR12):* argon2id hashing, HttpOnly + Secure + SameSite=Lax cookies, CSRF on state changes, 30-day idle session expiry, log redaction on auth payloads, TLS-only, server-enforced authorization. Drives the middleware chain composition and the secret-management surface in deploy.
- *Reliability (NFR13–NFR15):* deploy-time downtime ≤30s, panic-recovery middleware, multi-step writes within a single DB transaction. Forces `pgx` (or equivalent) transactional API and Fly.io rolling-deploy configuration.
- *Accessibility (NFR16–NFR19):* keyboard navigability, focus indicators, 4.5:1 contrast, semantic labels, VoiceOver smoke test of the critical flow. Frontend concern; informs RN-Web component choices.
- *Privacy (NFR20–NFR21):* minimal data collection, hard delete is real (no soft-delete tombstone). Forces a `DELETE` that issues actual SQL DELETEs in a transaction, not an `UPDATE deleted_at = NOW()`.
- *Maintainability & Observability (NFR22–NFR25):* structured logs (`slog`), per-request IDs in every log line and a response header, migration-driven reproducible schema, ≤5-command reproducible build. Drives the logging contract and the build pipeline shape.

### Scale & Complexity

- **Scale:** very small. Single intended user in v1. Five habits × ~30 check-offs/month = ~150 rows/month into `completions`, growing slowly. Total persistent state likely fits in tens of kilobytes after a year.
- **Concurrency:** effectively single-user. Multi-device usage by the same user (phone + desktop tab open simultaneously) is the realistic upper bound on concurrent writes per account. No write contention to design around.
- **Read/write ratio:** read-heavy. Every app open is one `GET /habits`; check-offs are bursty around morning/evening but small.
- **Primary technical domain:** full-stack web — Go HTTP API + RN/Expo/RNW SPA, packaged as a single binary deployed to Fly.io with co-located Postgres.
- **Complexity level:** low. Mainstream stack, single-tenant, no real-time/multi-tenant/regulatory complexity. The breadth of full-cycle slices (API + DB + auth + frontend + CI/CD + tests + obs) is broad but each slice is well-trodden.
- **Estimated architectural components:** 4 logical domain entities (User, Habit, Completion, Session) + 1 deployable binary (the Go server, which embeds the built SPA).

### Technical Constraints & Dependencies

**Locked by PRD (non-negotiable in architecture):**

- Language: Go (backend), TypeScript (frontend).
- HTTP routing: `net/http` + `chi`.
- Database: Postgres (Fly Postgres in v1).
- Migrations: `goose`.
- DB access: `database/sql` (or `pgx`) with a thin repository layer; `sqlc` deferred unless schema stabilizes.
- Frontend: React Native + Expo + `react-native-web`, TypeScript, TanStack Query for server-state, Expo Router for client routing.
- Auth: server-side opaque-token cookie sessions, `argon2id` password hashing, CSRF on state-changing routes.
- Architecture style: single Go binary serves `/api/...` (JSON) and `/` (built SPA from `embed.FS`). No CORS, no separate origins.
- Hosting: Fly.io. Single `FLY_API_TOKEN` secret in GHA.
- CI/CD: GitHub Actions. PR: tests + Playwright smoke. Merge to `main`: `flyctl deploy`.
- Observability: `slog` structured logs, panic-recovery middleware, request-ID middleware. No metrics in v1 unless trivial.
- Testing: Go `httptest` for handler + integration tests, Jest/RTL for frontend units, one Playwright happy-path e2e.

**Deferred to architecture (decisions this workflow will make):**

- Project / package layout for the Go module (e.g., `cmd/server/`, `internal/...`).
- Schema specifics for `users`, `habits`, `completions`, `sessions`, including indices and foreign-key cascade behavior.
- Exact query strategy for streak + 30-day % computation (single query with window functions, or per-habit with batching).
- CSRF token strategy (double-submit cookie vs synchronizer token vs framework helper).
- Session storage (Postgres-backed vs encrypted cookie value vs in-process map). Persistence implications differ.
- Build pipeline for embedding the Expo web bundle into the Go binary (build in GHA → produce `dist/`, then `go build` with `embed`).
- Test database strategy in CI (ephemeral Postgres service container vs in-process pgx test harness vs SQLite-in-tests-Postgres-in-prod).
- Local dev story (`docker compose` for Postgres vs Fly proxy).
- Error response shape (RFC 7807 problem details, custom envelope, or plain).
- Optimistic-concurrency or last-write-wins for the (rare) multi-device check-off race.

### Cross-Cutting Concerns Identified

These touch multiple components and must be designed coherently rather than per-feature:

1. **Timezone handling.** Stored on `User`, applied at every date computation (idempotency check, streak math, completion %). Wrong handling here breaks the entire Progress Visibility surface. Touches schema, request lifecycle, query layer, and tests (DST table-driven cases).
2. **Authorization (per-resource).** Every habit and completion access must verify `user_id = session.user_id`. Pattern: a middleware extracts session → `user_id`; every query is parameterized by it; every handler that takes a `:habit_id` URL param validates ownership before any other work. Single bug here = data leak across users.
3. **Request ID propagation.** Generated at ingress middleware, attached to a context value, logged on every line, returned as a response header (`X-Request-ID`), and embedded in the panic-recovery log. Bug here = lost ability to correlate logs to incidents.
4. **CSRF protection.** Applied to every state-changing route (POST/PUT/PATCH/DELETE). Strategy decision affects frontend (token in cookie + header, or per-request fetch).
5. **Transactional integrity.** Multi-step writes (habit delete cascading to completions; signup creating user + first session) must execute in a single DB transaction. Pattern: handlers receive a `*sql.DB`, open `BeginTx`, pass `*sql.Tx` to the repository layer.
6. **Same-origin asset serving.** Go binary routes `/api/*` to handlers, falls back to embedded SPA bundle (with `index.html` catch-all for client-side routes). The fallthrough rule needs careful ordering so API 404s don't accidentally serve `index.html`.
7. **Schema migration on deploy.** `goose` migrations must run before the binary starts serving requests (or at startup with a brief lock). Affects the Fly.io release-command configuration.
8. **Log redaction at the boundary.** Request/response logging middleware must redact known-sensitive fields (passwords, tokens) before emitting. Easier if the redact list is centralized rather than per-handler.
9. **Build embedding.** Frontend builds in GHA → output ends up in a directory the Go binary's `go:embed` directive picks up → `go build` produces a fat binary. Either the SPA bundle is committed (simple, ugly) or built fresh in CI (cleaner, requires Node in the CI image).

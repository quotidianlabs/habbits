---
title: Day-1 deploy design
date: 2026-06-06
status: approved
type: design
references:
  - docs/superpowers/specs/2026-06-05-habbits-foundation.md
---

# Day-1 deploy

## Context

First implementation slice from foundation §10 step 1: "Day 1: hello-world Go binary deployed to Fly.io with domain + TLS via GHA." The point is to kill the deploy yak shave — establish the CI/CD + Fly.io + TLS pipeline before any feature code lands — using a hello-world payload as the test traffic.

Repo state at start: empty Go project (no `go.mod`, no source files). Only `docs/` and a `.gitignore` with `.idea` exist. Working from `main`.

## Goal

A live `habbits.fly.dev` URL serving `GET /healthz → 200 OK` through the full middleware chain (panic-recovery → request-id → slog), deployed by GHA on every merge to `main`, with one Go test verifying the middleware wiring runs in PR CI.

## Non-goals

- Postgres, migrations, or any database wiring (foundation §10 step 2).
- Any `/api/...` route beyond `/healthz` (step 3).
- SPA serving via `embed.FS` (step 4).
- Real signup/login, CSRF, `argon2id` (step 5).
- Playwright e2e (step 6).
- Custom domain (`habbits.fly.dev` is sufficient; custom domain is post-Day-1).
- Sentry / error reporting; runtime metrics; structured config loading (env-var defaults only).

## File layout

```
.
├── .github/
│   └── workflows/
│       └── ci.yml
├── cmd/
│   └── server/
│       └── main.go
├── internal/
│   ├── middleware/
│   │   ├── recover.go
│   │   ├── requestid.go
│   │   └── slog.go
│   └── server/
│       ├── server.go
│       └── server_test.go
├── Dockerfile
├── .dockerignore
├── fly.toml
├── go.mod
└── go.sum
```

Module path: `github.com/<your-gh-handle>/habbits`. Handle confirmed at `go mod init` time during plan execution.

## Code shape

### Middleware chain order

Registered via `r.Use(...)` in this order — chi applies them in registration order, so the first registered is the outermost wrapper:

1. `Recoverer` — outermost. Catches panics from anything inside (including request-id and slog); logs the stack with the request ID if one is in context; returns a generic `500 Internal Server Error`.
2. `RequestID` — generates a UUID per request, attaches it to the request context under a typed key, and sets `X-Request-ID` on the response.
3. `SlogLogger` — reads the request ID from context and emits one structured `slog` line per request with `method`, `path`, `status`, `duration_ms`, `request_id`.

Outermost-recover is load-bearing: a panic during request-id generation or logging must not crash the process.

### Routes

- `GET /healthz` returns `Content-Type: application/json` with body `{"status":"ok"}` and status `200`.

No other routes on Day 1. A request to anything else gets chi's default `404`.

### main.go

Reads `PORT` from env (default `8080`). Builds the server. Calls `http.ListenAndServe`. No graceful shutdown on Day 1 — Fly's SIGTERM-then-SIGKILL handles it. (Graceful shutdown lands in step 5 when real connections matter.)

No env-loading framework, no `cobra`. Plain `os.Getenv`.

## Fly.io provisioning

These four steps are one-time and run by the developer locally, not by CI. The plan walks through them.

1. **`fly launch --no-deploy --name habbits`** — interactive. Pick a region (developer choice). Generates `fly.toml`, `Dockerfile`, `.dockerignore`. Commit the generated files after a hand-review.
2. **`fly deploy`** — first deploy from the CLI to verify the manual path works end-to-end. Confirm `https://habbits.fly.dev/healthz` returns `200 OK` with `{"status":"ok"}` and a non-empty `X-Request-ID` header.
3. **`fly tokens create deploy -x 999999h`** — generate a long-lived deploy token. Copy the value.
4. **`gh secret set FLY_API_TOKEN`** — paste the token. The plan documents the prompt.

`--no-deploy` on step 1 prevents `fly launch` from auto-deploying a half-tuned default image before the Dockerfile is committed and reviewed.

## CI workflow

Single file at `.github/workflows/ci.yml`. Two jobs:

- **test**
  - Trigger: `pull_request` (all branches).
  - Steps: checkout → `actions/setup-go@v5` (Go 1.22+) → `go test ./...`.
  - Expected runtime: ~1 minute.

- **deploy**
  - Trigger: `push` on `main`.
  - Needs: `test` (so a failing test on main blocks the deploy).
  - Steps: checkout → `superfly/flyctl-actions/setup-flyctl@master` → `flyctl deploy --remote-only` with `FLY_API_TOKEN` from secrets.
  - Expected runtime: 2–4 minutes.

Single workflow file rather than `ci.yml` + `deploy.yml`: the jobs share no other infra and stay under 50 lines together.

## Testing on Day 1

One test, `internal/server/server_test.go`. Uses `httptest.NewRequest` and the server's `http.Handler` directly (no network). Asserts:

- `GET /healthz` returns status `200`.
- Response body parses to `{"status":"ok"}`.
- The `X-Request-ID` response header is present and non-empty.

That single test exercises the entire middleware chain end-to-end and gives PR CI something meaningful to run. No per-middleware unit tests on Day 1 — they would add coverage without revealing new failure modes the integration test misses.

## Quality bars active on Day 1

From foundation §6, only these are relevant at Day 1:

- **Reliability:** panic-recovery middleware is wired and tested (will be exercised properly in a follow-up step's panic test).
- **Observability:** `slog` structured logs, request ID propagated in context, logs, and `X-Request-ID` response header.
- **CI gates:** `go test` blocks deploy.

Performance, security, accessibility, and privacy bars are not yet exercisable — they apply to features that don't exist yet.

## Deferred decisions

- **Graceful shutdown** — deferred to step 5 (auth) when in-flight connections start mattering.
- **DB-aware healthz** — `/healthz` returns static OK on Day 1. A `/readyz` that pings Postgres lands in step 2.
- **Custom domain + cert** — `*.fly.dev` is the Day-1 surface.
- **Structured config loading** — plain `os.Getenv` until something needs more.

## Trade-offs accepted

- **Single integration test, no per-middleware units.** Less code coverage in absolute terms, but it tests the wiring (which is where Day-1 bugs would live) rather than each middleware in isolation. Per-middleware tests added when middlewares grow conditional logic.
- **No graceful shutdown.** Fly's SIGTERM-then-SIGKILL is enough until real user sessions exist. The cost is reintroducing the shutdown plumbing in step 5; the benefit is one less moving part on Day 1.
- **`fly launch` is interactive.** The plan can't fully script the provisioning. Cost: the developer runs commands by hand and inspects output. Benefit: idiomatic Fly setup, generated files are reviewable, no hand-authored `fly.toml` to maintain alongside Fly's defaults.
- **Single workflow file, not split.** Cost: a future split (if jobs diverge) is a rename. Benefit: one place to scan; matches the project's general preference for boring fundamentals over upfront structure.

## What success looks like

Definition of done for Day 1:

1. `https://habbits.fly.dev/healthz` returns `200 OK` with `Content-Type: application/json`, body `{"status":"ok"}`, and a non-empty `X-Request-ID` header.
2. The Fly deploy logs include one structured `slog` line per request, with the request ID.
3. A new PR runs the `test` job and shows green.
4. A merge to `main` runs `deploy` and the change reaches `habbits.fly.dev` within 5 minutes.
5. `FLY_API_TOKEN` is the only secret configured in the GitHub repo.

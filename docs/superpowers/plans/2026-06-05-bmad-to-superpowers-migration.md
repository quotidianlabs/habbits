# BMad → Superpowers Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the Habbits project from BMad to Superpowers by archiving the four BMad artifacts to `docs/bmad-legacy/` and writing a single ~150-line foundation spec at `docs/superpowers/specs/2026-06-05-habbits-foundation.md` that future feature specs will reference.

**Architecture:** Doc-only migration, no code changes. Existing BMad files are currently untracked in `docs/`. Move them to `docs/bmad-legacy/`, hand-write the foundation spec by distilling content from the legacy PRD, architecture analysis, and briefs, then commit. `.claude/` configuration is unchanged.

**Tech Stack:** None — markdown documents only. Tools: git, file system operations, Write/Edit.

**Source design:** `docs/superpowers/specs/2026-06-05-bmad-to-superpowers-migration-design.md` (already committed).

---

### Task 1: Archive BMad files to `docs/bmad-legacy/`

**Files:**
- Move: `docs/product-brief-habbits.md` → `docs/bmad-legacy/product-brief-habbits.md`
- Move: `docs/product-brief-habbits-distillate.md` → `docs/bmad-legacy/product-brief-habbits-distillate.md`
- Move: `docs/prd.md` → `docs/bmad-legacy/prd.md`
- Move: `docs/architecture.md` → `docs/bmad-legacy/architecture.md`

The destination directory `docs/bmad-legacy/` already exists (created during brainstorm).

- [ ] **Step 1: Verify source files exist and destination is empty**

Run: `ls docs/*.md && ls docs/bmad-legacy/`
Expected: lists the four BMad files in `docs/`, empty listing for `docs/bmad-legacy/`.

- [ ] **Step 2: Move all four BMad files**

Run:
```bash
mv docs/product-brief-habbits.md docs/bmad-legacy/
mv docs/product-brief-habbits-distillate.md docs/bmad-legacy/
mv docs/prd.md docs/bmad-legacy/
mv docs/architecture.md docs/bmad-legacy/
```

- [ ] **Step 3: Verify the move**

Run: `ls docs/ && ls docs/bmad-legacy/`
Expected: `docs/` contains only `bmad-legacy/` and `superpowers/`. `docs/bmad-legacy/` contains all four files.

Run: `git status --short`
Expected: if the originals were tracked in a prior commit, `git status` shows them as deleted (` D`) and the new files under `docs/bmad-legacy/` as untracked (`??`). Task 3 stages both sides together with `git add -A` so git records renames. If they were untracked, only `??` markers appear. Either is acceptable; Task 3 handles both.

---

### Task 2: Write the foundation spec

**Files:**
- Create: `docs/superpowers/specs/2026-06-05-habbits-foundation.md`

Hand-write the foundation spec by distilling content from the archived BMad docs. The target is **~150 lines, scannable, no padding**. Each section is described below with its source content. Reference source paths use the post-archive locations (`docs/bmad-legacy/...`).

- [ ] **Step 1: Write the frontmatter and document header**

Open `docs/superpowers/specs/2026-06-05-habbits-foundation.md` and write:

```markdown
---
title: Habbits foundation spec
date: 2026-06-05
status: locked
type: foundation
---

# Habbits foundation

This spec is the constitution for the Habbits project. Future feature specs and implementation plans reference it by section (e.g., "per foundation §3, streak resets on missed day") rather than restating shared rules. Detailed FR/NFR text lives in `docs/bmad-legacy/prd.md` and is referenced, not duplicated.
```

- [ ] **Step 2: Write §1 Identity**

One paragraph. Source: `docs/bmad-legacy/product-brief-habbits-distillate.md` → "Project Identity" + `docs/bmad-legacy/prd.md` → "Executive Summary".

Content to convey:
- Habbits is a personal habit tracker with an inverted default: user-owned, mutable, hard-deletable records.
- Dual purpose: daily-driver tracker replacing coach.me; full-cycle dev exercise.
- v1 scope: five daily checkbox habits (exercises, medicine, workout, reading, meditation), two metrics (current streak + 30-day completion %), web only.
- Single user in v1 (the author). Mobile is post-MVP from the same codebase.
- Time horizon: 1–3 weeks solo work.

Write under `## 1. Identity`.

- [ ] **Step 3: Write §2 Locked decisions**

Bullets only. Source: `docs/bmad-legacy/product-brief-habbits-distillate.md` → "Locked decisions" + `docs/bmad-legacy/prd.md` → "Technical Architecture Considerations".

Group bullets under sub-headers `**Backend:**`, `**Frontend:**`, `**Auth:**`, `**Architecture:**`, `**Hosting:**`, `**CI/CD:**`, `**Testing:**`, `**Observability:**`. Each one short line.

Content per group:
- Backend: Go, `net/http` + `chi`, Postgres, `goose` migrations, `database/sql` + thin repo, `sqlc` deferred.
- Frontend: React Native + Expo + `react-native-web`, TypeScript, TanStack Query for server state, Expo Router for client routing.
- Auth: server-side opaque-token cookie sessions, HttpOnly + Secure + SameSite=Lax, `argon2id`, CSRF on state-changing routes.
- Architecture: single Go binary serves `/api/...` (JSON) and `/` (built SPA via `embed.FS`). Same-origin. No CORS.
- Hosting: Fly.io app + Fly Postgres. Single `FLY_API_TOKEN` secret in GHA.
- CI/CD: GitHub Actions. PR runs `go test`, frontend units, Playwright smoke. Merge to `main` runs `flyctl deploy`.
- Testing: Go `httptest` for handlers + integration, Jest/RTL for frontend units, one Playwright happy-path e2e.
- Observability: `slog` structured logs, request IDs, panic-recovery middleware. No metrics in v1.

Write under `## 2. Locked decisions`.

- [ ] **Step 4: Write §3 Product rules**

Six bullets. Source: `docs/bmad-legacy/product-brief-habbits-distillate.md` → "Product Rules".

Bullets verbatim in spirit:
- **Day** = user's local calendar date, computed from a `timezone` field on the user record.
- **Streak** = consecutive prior local days (including today, if checked) with ≥1 check-off in user TZ. Missed day → reset to 0.
- **Completion %** = rolling 30-day window: completed-days ÷ days-since-creation (capped at 30). Excludes today when not yet checked.
- **Delete** = hard delete of habit + all check-offs. No undo, no tombstone.
- **Edit** = rename only in v1. Cadence is daily and not editable.
- **Check-off** = today only in v1. No retroactive editing.

Write under `## 3. Product rules`.

- [ ] **Step 5: Write §4 Data model sketch**

Source: `docs/bmad-legacy/product-brief-habbits-distillate.md` → "Data Model" + `docs/bmad-legacy/architecture.md` → "Scale & Complexity" (entity list).

Four entities, key fields only. Use a sub-bulleted format:

- `User`: `id`, `email`, `password_hash`, `timezone`, `created_at`.
- `Habit`: `id`, `user_id`, `name`, `created_at`. Hard delete (no `deleted_at`).
- `Completion`: `habit_id`, `user_id`, `local_date`, `created_at`. Unique on `(habit_id, local_date)`.
- `Session`: `id`, `user_id`, `expires_at`. Opaque token as cookie value.

Add a one-line note: "Schema specifics (indexes, FK cascade behavior, column types) are decided per implementation plan."

Write under `## 4. Data model sketch`.

- [ ] **Step 6: Write §5 Functional capabilities**

Source: `docs/bmad-legacy/prd.md` → "Functional Requirements" (FR1–FR32 grouped under 6 headers).

For each of the six FR groups, write the group name as a sub-header, then ONE short sentence summarizing the capability area, ending with a reference to the FR range. Do not list individual FRs.

- `### Account management` — Email/password sign-up, sign-in, sign-out; multi-device sessions; TZ captured at signup; unique-email enforcement. See `docs/bmad-legacy/prd.md` FR1–FR8.
- `### Habit management` — Create / rename / hard-delete with confirmation; per-user isolation; no restore mechanism. See FR9–FR15.
- `### Daily check-off` — Today-only, idempotent per (habit, local-date); reflected without full reload. See FR16–FR20.
- `### Progress visibility` — Computed streaks and 30-day completion %, no punishment messaging. See FR21–FR25.
- `### Cross-device access` — Mobile-first portrait layout, ≥44pt tap targets, keyboard navigability on desktop. See FR26–FR28.
- `### System behavior` — Auth required on all CRUD; CSRF on state changes; per-resource authorization. See FR29–FR32.

Write under `## 5. Functional capabilities`.

- [ ] **Step 7: Write §6 Quality bars**

Source: `docs/bmad-legacy/prd.md` → "Non-Functional Requirements" (NFR1–NFR25 across 6 categories).

For each category, one short paragraph (1–2 sentences) summarizing the bar plus a reference to the NFR range.

- `### Performance` — FCP <2s, TTI <3.5s on mobile 4G; GET /habits median <100ms; check-off median <80ms; gzipped JS bundle ≤350KB. The 100ms target forbids N+1 — habit list must compute streaks and 30-day % in a single batched query. See `docs/bmad-legacy/prd.md` NFR1–NFR5.
- `### Security` — `argon2id` with OWASP params; HttpOnly+Secure+SameSite=Lax cookies; CSRF on state changes; 30-day idle session expiry; log redaction of secrets; TLS-only; server-side authorization on every resource. See NFR6–NFR12.
- `### Reliability` — No formal SLA; deploys ≤30s of in-flight unavailability; panic-recovery middleware required; multi-step writes in a single transaction. See NFR13–NFR15.
- `### Accessibility` — Pragmatic floor: keyboard reachability + visible focus, 4.5:1 contrast, semantic labels, VoiceOver smoke test of the critical flow. No formal WCAG audit. See NFR16–NFR19.
- `### Privacy` — Collect only what's needed (email, password hash, timezone, habits, check-offs). Hard delete is real — no soft-delete tombstone. See NFR20–NFR21.
- `### Observability` — Structured `slog` logs, unique request ID per HTTP request propagated through logs and `X-Request-ID` response header; migration-driven reproducible schema; ≤5-command reproducible build. See NFR22–NFR25.

Write under `## 6. Quality bars`.

- [ ] **Step 8: Write §7 Cross-cutting concerns**

Source: `docs/bmad-legacy/architecture.md` → "Cross-Cutting Concerns Identified" (nine numbered items).

One sentence per concern. Use a numbered list.

1. **Timezone handling.** User TZ stored on `User` record at signup; applied at every date computation — idempotency, streak math, completion %. Wrong handling here breaks all of §3.
2. **Per-resource authorization.** Every habit and completion access must verify `user_id = session.user_id`. Single bug here = cross-user data leak.
3. **Request-ID propagation.** Generated at ingress middleware, attached to context, logged on every line, returned as `X-Request-ID`, and included in panic-recovery logs.
4. **CSRF protection.** Applied to all POST/PUT/PATCH/DELETE routes. Token strategy (double-submit cookie vs synchronizer) decided in the auth plan.
5. **Transactional integrity.** Multi-step writes (habit delete cascading to completions; signup creating user + first session) execute in a single DB transaction.
6. **Same-origin asset serving.** Go binary routes `/api/*` to handlers; falls through to embedded SPA bundle with catch-all returning `index.html` for client routes. Ordering must not let API 404s serve `index.html`.
7. **Schema migration on deploy.** `goose` migrations run before the binary serves requests. Wired in via Fly release-command.
8. **Log redaction.** Centralized redact list for passwords, session tokens, CSRF tokens; applied at the logging middleware boundary, never per-handler.
9. **Build embedding.** Frontend built in GHA, output embedded into the Go binary via `go:embed`. The CI image needs Node.

Write under `## 7. Cross-cutting concerns`.

- [ ] **Step 9: Write §8 Out of scope**

Source: `docs/bmad-legacy/product-brief-habbits-distillate.md` → "Rejected Ideas" + `docs/bmad-legacy/prd.md` → "Product Scope → Explicitly out of MVP".

Single bullet list, terse:

- Password reset (deferred — requires email infra).
- Mobile apps (post-MVP via same RN+Expo codebase).
- Reminders / push notifications.
- Non-daily cadence; quantity-based completion; retroactive check-offs.
- Heatmap, weekday analytics, time-of-day stats.
- Social, gamification, AI insights, Apple Health / Google Fit.
- CSV/JSON data export (high-priority post-MVP — see brief).
- JWT auth, separate origins, OIDC for CI deploy, `sqlc`, SQLite, single-user mode.

Write under `## 8. Out of scope`.

- [ ] **Step 10: Write §9 Kill criteria**

Source: `docs/bmad-legacy/product-brief-habbits.md` → "Kill Criteria".

Four bullets, each one line:

- RN+Expo+RNW setup costing >2 days → drop to plain React + Vite for web; accept divergent mobile codebase later.
- Auth not working by end of week 2 → drop to single-user mode with hardcoded account.
- Day-7 dogfood target slipping >3 days → cut a feature; do not extend the timeline.
- Any backlog item that "feels almost free" mid-sprint → blocked from landing until ≥7 consecutive dogfooding days.

Write under `## 9. Kill criteria`.

- [ ] **Step 11: Write §10 Build order pointer**

Source: `docs/bmad-legacy/product-brief-habbits-distillate.md` → "Recommended Build Order".

One sentence + a numbered list. End with a pointer to the first plan.

Content:

> Build order kills the largest yak shaves first. The first implementation plan implements step 1.

1. Day 1: hello-world Go binary deployed to Fly.io with domain + TLS via GHA.
2. Schema + repo layer (Postgres + goose migrations).
3. JSON API behind bearer-token middleware: `GET /habits`, `POST /habits/:id/checkoffs`, `DELETE /habits/:id`.
4. Minimal RN+Expo+RNW web UI: list, today's checkbox, streak, delete. Deploy. **Dogfood here, end of week 1.**
5. Replace bearer-token with real signup/login (cookie sessions, CSRF, argon2id).
6. Wire one Playwright smoke into GHA.
7. Week 2–3 stretch: pick one of best-streak, edit UI, mobile parity, password reset.

Write under `## 10. Build order`.

- [ ] **Step 12: Verify line count and overall shape**

Run: `wc -l docs/superpowers/specs/2026-06-05-habbits-foundation.md`
Expected: roughly 100–200 lines (target ~150). If significantly over 200, the spec drifted into restating PRD detail — trim by replacing prose with FR/NFR references.

Run: `head -50 docs/superpowers/specs/2026-06-05-habbits-foundation.md`
Expected: frontmatter, header paragraph, §1 Identity, start of §2.

---

### Task 3: Commit the migration

**Files:** all of `docs/bmad-legacy/` (four files) and `docs/superpowers/specs/2026-06-05-habbits-foundation.md`.

- [ ] **Step 1: Verify git sees the expected changes**

Run: `git status --short`
Expected: BMad originals at `docs/*.md` show as deleted (` D`) if they were previously tracked, OR are entirely absent if they were untracked. The new files in `docs/bmad-legacy/` show as untracked (`??`). `docs/superpowers/specs/2026-06-05-habbits-foundation.md` shows as untracked (`??`).

- [ ] **Step 2: Stage the migration files**

Use `git add -A docs/` so that both the deletions of the originals (if previously tracked) and the additions in `docs/bmad-legacy/` and `docs/superpowers/specs/` are staged together. This lets git detect renames in the resulting diff.

Run:
```bash
git add -A docs/
```

- [ ] **Step 3: Verify staging**

Run: `git status --short`
Expected: only staged changes remain. If the BMad originals were previously tracked, the four files appear as renames (`R  docs/...md -> docs/bmad-legacy/...md`); otherwise they appear as new files (`A  docs/bmad-legacy/...md`). The foundation spec appears as a new file (`A  docs/superpowers/specs/2026-06-05-habbits-foundation.md`). No unstaged changes.

Run: `git diff --staged --stat`
Expected: shows the staged file changes. If renames are detected, they appear with rename arrows; otherwise as adds + deletes. Total: five files changed (four archived + one new foundation spec).

- [ ] **Step 4: Commit**

Run:
```bash
git commit -m "$(cat <<'EOF'
docs: archive BMad artifacts and add Habbits foundation spec

Move four BMad documents (two briefs, PRD, half-finished
architecture) into docs/bmad-legacy/ as frozen reference. Add
the ~150-line foundation spec at
docs/superpowers/specs/2026-06-05-habbits-foundation.md
distilled from those sources; future feature specs reference
it by section rather than restating shared rules.

Per the migration design at
docs/superpowers/specs/2026-06-05-bmad-to-superpowers-migration-design.md.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 5: Verify commit landed clean**

Run: `git status && git log --oneline -5`
Expected: working tree clean; two commits on `main` (the migration-design commit and this archive-and-foundation commit).

---

## Self-review notes

- **Spec coverage:** The migration design enumerates a file layout, 10 foundation-spec sections, 4 migration steps, and a future-workflow shape. Tasks 1–3 cover all 4 migration steps. The 10 foundation-spec sections each have a dedicated step in Task 2. Future workflow needs no implementation — it's process documentation.
- **Placeholder scan:** No TBDs. Every step has either concrete commands, concrete content to write, or a verification check. Sections referencing FR/NFR ranges are intentional pointers, not placeholders — the source material exists in the archived PRD.
- **Type consistency:** No code, no types. Path references (`docs/bmad-legacy/...`, `docs/superpowers/specs/...`) are consistent across the design and plan.
- **Known efficiency:** Each foundation-spec section is its own step. A subagent could batch sections 1–10 in one Write call after reading the source docs. Per-step granularity is for review checkpointing, not separate Write calls.

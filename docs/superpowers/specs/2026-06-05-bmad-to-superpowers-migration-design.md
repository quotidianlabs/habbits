---
title: BMad → Superpowers migration design
date: 2026-06-05
status: approved
type: design
---

# BMad → Superpowers migration

## Context

Habbits is greenfield (no commits, no code) and was scaffolded with BMad: two product briefs, a fully complete PRD (32 FRs, 25 NFRs), and a half-finished architecture document. The PRD/brief content is rigorous and worth keeping. BMad's process — PRD → architecture → epics → stories → dev-story — is heavier than wanted going forward.

This design migrates the project to Superpowers' lighter brainstorm → spec → plan → execute loop, preserving the validated requirements without inheriting BMad's intermediate-artifact ceremony.

## Goals

- Preserve the rigor in the PRD and briefs (don't redo validated work).
- Drop BMad's PRD/architecture/epics/stories/dev document chain going forward.
- Establish a single project-foundation spec that future feature specs reference, so each feature gets one short spec + one plan + execution rather than the BMad sequence.
- Leave room for normal Superpowers workflow tools (TDD, systematic-debugging, verification-before-completion) to govern code without further setup.

## Non-goals

- Removing BMad skills from `.claude/`. They cohabit fine; unused skills are zero cost.
- Re-litigating any locked decision in the PRD (stack, auth, hosting, product rules).
- Producing a complete architecture document. Architecture decisions surface inside each feature plan's brainstorm.

## File layout

```
docs/
├── bmad-legacy/                              # archived BMad artifacts (frozen)
│   ├── product-brief-habbits.md
│   ├── product-brief-habbits-distillate.md
│   ├── prd.md
│   └── architecture.md
└── superpowers/
    ├── specs/
    │   ├── 2026-06-05-bmad-to-superpowers-migration-design.md   # this doc
    │   └── 2026-06-05-habbits-foundation.md                     # written during migration
    └── plans/                                                    # first plan lands here
```

`bmad-legacy/` is a freeze, not a working directory — files there are read-only references.

## The foundation spec

`docs/superpowers/specs/2026-06-05-habbits-foundation.md`, ~150 lines, sections in order:

1. **Identity** — one paragraph: what Habbits is, dual purpose, single-user v1.
2. **Locked decisions** — bullets: stack (Go + chi + Postgres + RN/Expo/RNW), auth (cookie sessions, argon2id, CSRF), hosting (Fly.io same-origin single binary), CI/CD (GHA → flyctl), testing (httptest + Playwright), observability (slog + request IDs).
3. **Product rules** — six bullets: day = user TZ, streak formula, 30-day % formula, hard delete, rename-only edit, today-only check-off.
4. **Data model sketch** — User, Habit, Completion, Session with key fields.
5. **Functional capabilities** — grouped headers (Account, Habit, Check-off, Progress, Cross-device, System) with one short line per area. References `bmad-legacy/prd.md` § Functional Requirements for full FR text rather than restating 32 numbered items.
6. **Quality bars** — compressed NFRs: perf (FCP/TTI/latency/bundle), security (argon2id/cookie flags/CSRF/TLS), reliability (transactional writes, panic recovery), a11y floor, privacy, observability.
7. **Cross-cutting concerns** — lifted from `bmad-legacy/architecture.md` § Cross-Cutting Concerns: timezone handling, per-resource authz, request-ID propagation, CSRF, transactional integrity, same-origin asset serving, schema migration on deploy, log redaction, build embedding. One sentence each.
8. **Out of scope** — short bullet list (no password reset, no mobile, no reminders, no quantity, no heatmap, no analytics, no social, no AI, no health integrations).
9. **Kill criteria** — four pre-authorized scope cuts from the brief.
10. **Build order pointer** — sentence + bullet list referencing the brief's recommended sequence; first plan implements step 1 (Day-1 hello-world deploy).

The foundation spec is the constitution. Feature specs cite it by section (e.g., "per foundation §3, streak resets on missed day") instead of restating shared rules.

## Migration steps (to be sequenced in the plan)

1. Create `docs/bmad-legacy/`, `docs/superpowers/specs/`, `docs/superpowers/plans/` (specs and plans dirs already created during brainstorm).
2. `git mv` the four BMad files from `docs/` into `docs/bmad-legacy/`.
3. Write `docs/superpowers/specs/2026-06-05-habbits-foundation.md` per the section list above. Hand-write each section; do not template-fill. Cite legacy doc paths where details are deferred.
4. Initial commit: `docs: migrate from BMad to Superpowers; archive originals to bmad-legacy/`. Repo currently has no commits, so this is commit #1.

No changes to `.claude/`. No code changes. No new tooling.

## Future workflow

Per-feature loop, anchored to the foundation spec:

```
brainstorming → feature spec (references foundation §N)
              → writing-plans → implementation plan in docs/superpowers/plans/
              → executing-plans / TDD / verification-before-completion
              → finishing-a-development-branch
```

First use after migration: brainstorm Day-1 deploy (hello-world Go binary → Fly.io → GHA → TLS), producing `2026-06-05-day-1-deploy-skeleton-spec.md` then a plan. Each subsequent slice (auth, habits CRUD, check-off, streaks, frontend skeleton, Playwright smoke) gets its own spec + plan, all referencing the foundation.

## Trade-offs accepted

- **Foundation spec compresses, doesn't replace.** Feature specs cite legacy PRD by section for FR text. Cost: occasional jump to the legacy doc. Benefit: foundation stays ~150 lines and scannable.
- **No architecture document.** The half-done `architecture.md` is archived; architecture surfaces per-plan. Cost: no single place to see the whole system shape. Benefit: no half-finished artifact pretending to be the spec.
- **BMad skills remain installed.** They are not removed from `.claude/`. Cost: unused skills clutter the available-skills list. Benefit: zero risk of breaking anything; trivially reversible.

## Out of scope for this migration

- Writing any feature spec or implementation plan. That happens after migration.
- Touching `.claude/` configuration.
- Writing code, scaffolding the Go module, or initializing the frontend project.
- Deciding architecture-level questions deferred in the legacy `architecture.md` (project layout, schema specifics, session storage, CSRF strategy, build embedding). Each surfaces in its relevant feature plan.

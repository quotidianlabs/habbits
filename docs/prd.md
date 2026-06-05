---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-02b-vision
  - step-02c-executive-summary
  - step-03-success
  - step-04-journeys
  - step-05-domain (skipped — low complexity, general domain)
  - step-06-innovation (skipped — no novel mechanics; differentiation is product principle, not technical)
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
  - step-12-complete
status: complete
releaseMode: phased
classification:
  projectType: web_app
  domain: general
  complexity: low
  projectContext: greenfield
inputDocuments:
  - /Users/kevinsmith/src/habbits/docs/product-brief-habbits.md
  - /Users/kevinsmith/src/habbits/docs/product-brief-habbits-distillate.md
workflowType: prd
project_name: Habbits
user_name: Kevin
date: 2026-05-11
documentCounts:
  briefs: 2
  research: 0
  brainstorming: 0
  projectDocs: 0
greenfield: true
---

# Product Requirements Document — Habbits

**Author:** Kevin
**Date:** 2026-05-11

## Executive Summary

Habbits is a personal habit tracker built around an inverted default: habits are user-owned records, fully mutable, hard-deletable, and (post-MVP) exportable. The v1 problem space is narrow — five daily checkbox habits (exercises, medicine, workout, reading, meditation) tracked across web and, post-MVP, mobile, with two metrics: current streak and 30-day completion percentage.

The product serves a single primary user — the author — replacing coach.me as a daily-driver tracker. The build doubles as a deliberate full-cycle development exercise across Go + Postgres backend, React Native + Expo + react-native-web frontend, cookie-session auth, GitHub Actions CI/CD, automated tests at unit/integration/e2e levels, and basic structured-logging observability. Time horizon: 1–3 weeks of solo work. Day-7 dogfood target: deployed URL on phone, "medicine" checked off, streak = 1, state persists across reload.

### What Makes This Special

The differentiating behavior is destructive, not constructive: **the user changes their mind about a habit, deletes it, and the app responds with "okay, gone."** No undo, no tombstone, no negotiation. Existing trackers — coach.me, Habitica, Streaks, HabitKit, Loop — share an industry-wide failure mode of locking habits after creation, paywalling deletion or export, and treating user data as platform property. Habbits inverts that default as a design principle, not a marketing feature.

The core insight: the tracker that lets users abandon a habit cleanly is the tracker they'll trust with the next one. Adherence dies from inflexibility, not from the absence of gamification — so Habbits ships none of the latter (no XP, avatars, streaks-as-currency, social, AI insights) and instead invests in the boring fundamentals (data ownership, clean deletion, idempotent check-off, correct streak math across timezones and DST).

The unfair advantage is execution context: the author is the user, the designer, and the builder. Decisions ship in minutes, not quarters.

## Project Classification

- **Project Type:** `web_app` — v1 ships as a responsive web application built on React Native + Expo + `react-native-web`, served from a same-origin Go binary. Mobile (iOS + Android) is explicit post-MVP scope from the same codebase, but is not in v1.
- **Domain:** `general` — personal productivity / habit tracking. No regulated industry, no compliance regime, no domain-specific certifications. Standard requirements: basic security, performance, accessibility, user experience.
- **Complexity:** `low` — single-developer build, mainstream stack, no novel protocols, no real-time or multi-tenant complexity. Engineering *breadth* is broad (full-cycle slices), depth per slice is "competent and idiomatic," not specialized.
- **Project Context:** `greenfield` — empty repository, no prior code or infrastructure. The product brief and its distillate (`docs/product-brief-habbits.md`, `docs/product-brief-habbits-distillate.md`) are the only existing artifacts.

## Success Criteria

### User Success

The user is the author. Success is daily-driver adoption with no friction tax.

- **Adoption (binary):** all five core habits (exercises, medicine, workout, reading, meditation) are created in Habbits and checked off daily for at least 7 consecutive days post-deploy.
- **Replacement (binary):** within 14 days of v1 deploy, the author has not opened coach.me to log a habit.
- **Aha moment (observable):** within the first 30 days, the author creates at least one habit, deletes it, creates a replacement — exercising the "okay, gone" thesis on real data without hesitation.
- **No-friction tax (qualitative):** no instance where the tool requires more than 3 taps to check off today's habit on mobile web; no instance where the tool blocks the user from a destructive action they want to take.

### Project Success (in lieu of "Business Success")

This is a personal pet project, not a commercial product — there is no revenue, user base, or market goal. "Project success" reframes the category around delivery and learning outcomes.

- **Day-7 dogfood target (binary):** by end of week 1, the deployed URL serves the web app; the author signs up, creates one habit, checks it off from a phone browser, sees streak = 1, and state persists across reload.
- **Full-cycle slice coverage (binary, 7-of-7):** by v1 ship, every named learning slice has a concrete artifact in the repo:
  - Go API (`net/http` + `chi`, versioned routes, three middlewares: recoverer / request-id / auth).
  - Postgres schema + `goose` migrations checked in; schema rebuildable from zero with one command.
  - Auth: signup + login + logout (cookie sessions, `argon2id`, CSRF on state-changing routes). Password reset explicitly deferred.
  - Frontend: real RN + Expo + `react-native-web` project (not a stub) running web in v1.
  - CI/CD: GitHub Actions running `go test`, frontend unit tests, and one Playwright e2e on PRs; `flyctl deploy` on merge to `main`.
  - Tests: ≥1 Go `httptest` integration test per handler; one Playwright happy-path e2e.
  - Observability: `slog` structured logs with request IDs; panic-recovery middleware proven by a deliberate panic test.
- **Time-to-merged-change (qualitative target):** "decisions in minutes, not quarters" — informally tracked as the median elapsed time between identifying a personal-use friction and shipping the fix. No absolute number; tracked as a journal entry only.

### Technical Success

The product must be correct, secure-by-default, and operationally trivial.

- **Correctness (the load-bearing one):**
  - Streak math is correct across DST transitions and user-timezone boundaries. Covered by a table-driven Go test that includes spring-forward and fall-back scenarios in at least two timezones.
  - Check-off is idempotent: a duplicate `POST /habits/:id/checkoffs` for the same day does not change state or counts.
  - Hard delete of a habit removes the habit row and all associated check-off rows; verified by integration test.
- **Security minimums:** specified as NFR6–NFR12 in `## Non-Functional Requirements → Security` (password hashing, cookie attributes, CSRF, TLS, log redaction, server-side authorization).
- **Performance baseline:** specified as NFR1–NFR5 in `## Non-Functional Requirements → Performance` (FCP, TTI, API latency, bundle size).
- **Availability:** no formal SLA — personal tool, brief downtime during deploys acceptable. Detail in NFR13.
- **Critical e2e flow (must pass in CI on every PR):**
  > sign up → create habit → check off today → see streak = 1 → reload → state persists

### Measurable Outcomes

Concrete, testable conditions for "v1 is done":

| # | Outcome | Verification |
|---|---|---|
| 1 | Single deployed URL is live with TLS | `curl -I https://<domain>` returns 200, valid cert |
| 2 | Sign-up + login + logout work end-to-end | Playwright e2e passes in CI |
| 3 | Five habits created and check-off persisted across reload | Manual dogfood + e2e |
| 4 | Streak = consecutive prior days of check-off (incl. today) in user TZ | Go table-driven test passes including DST cases |
| 5 | 30-day completion % matches spec (excludes today if unchecked; capped denominator) | Go unit test + manual spot check |
| 6 | Habit delete removes habit + all check-offs | Integration test |
| 7 | CI runs full test suite + Playwright smoke on every PR | GitHub Actions workflow file checked in, badge green |
| 8 | Merge to `main` deploys to Fly.io via `flyctl` | Last 3 commits on `main` show successful deploy runs |
| 9 | Author has not used coach.me for 14 consecutive days post-deploy | Author's journal |
| 10 | Kill-criteria triggers, if any, were honored | Retrospective note in repo |

## Product Scope

### MVP — Minimum Viable Product (Week 1–3)

**In scope:**

- Multi-user accounts: sign-up, login, logout. Password reset deferred.
- Habit CRUD with constraints: create, rename (text only), hard delete. No frequency editing — daily only.
- Daily check-off (boolean, today only — no retroactive editing).
- Per-habit metrics: current streak, 30-day completion percentage.
- Web app, responsive, built as a real RN + Expo + `react-native-web` project.
- Go API + Postgres on Fly.io, served same-origin from a single Go binary.
- CI/CD via GitHub Actions: tests on PR, `flyctl deploy` on merge.
- Automated tests: Go `httptest` handler/integration tests + one Playwright happy-path e2e.
- Observability: `slog` structured logs with request IDs, panic-recovery middleware.

**Explicitly out of MVP** (see brief for full backlog with rationales):

- Password reset (hides email infra).
- Mobile apps (iOS/Android) — same RN codebase, post-MVP packaging.
- Reminders / push notifications.
- Non-daily cadence; quantity-based completion; retroactive check-offs.
- Heatmap / weekday analytics / time-of-day stats.
- Social, gamification, AI insights, Apple Health / Google Fit.
- CSV/JSON data export (high-priority post-MVP, half-day add that converts data-ownership from principle to demo).

### Growth Features (Post-MVP, in priority order)

1. **CSV / JSON data export** — closes the data-ownership principle. Half-day. Highest priority.
2. **Mobile parity (iOS + Android via Expo Go)** — same RN+Expo codebase, packaging exercise. Highest learning value.
3. **Password reset** — requires email provider (Resend/SES). 1–2 days.
4. **Best-streak metric** per habit. <half-day.
5. **Heatmap visualization** (GitHub-style contribution grid per habit). 1 day.
6. **Reminders / push notifications** via Expo Push / FCM / APNs. 3–5 days.
7. **Non-daily cadence** (weekly, custom schedule). Changes streak math — schema migration needed.
8. **Retroactive check-offs** (edit "yesterday"). Schema-light, UX-light.

### Vision (Future, 2–3 year shape)

A small, opinionated, no-bullshit habit tracker that an individual can run for themselves or a few trusted accounts without trusting a vendor. Plausible expansions:

- **Self-hostable** (single Go binary + Postgres) with `docker compose` quickstart.
- **Permissive-license OSS reference** for full-cycle Go + RN + Expo projects.
- **Lightweight accountability** — share a single habit's streak with one or two trusted accounts, no social feed, no public profile.
- **Richer analytics** — weekday patterns, completion trends, time-of-day correlations.
- **Quantity-based habits** alongside boolean (reading 30 min, 5 sets, etc.).

Out of vision regardless of time: avatars, XP, currency-streaks, public habit feeds, AI-generated habit suggestions, Habitica-style gamification.

## User Journeys

There is one user role in Habbits v1: **the account owner**. No admin role, no support role, no API consumer role, no moderator role — these are explicitly omitted (see *Roles Not Present* at the end of this section).

The journeys below cover the four interactions that drive v1's functional surface: onboarding, daily check-off, the destructive "okay, gone" interaction, and the recovery path when adherence breaks.

---

### Journey 1: First Habit (Onboarding)

**Persona:** Kevin, the author. Wants to replace coach.me with something he controls. Has five habits in mind: exercises, medicine, workout, reading, meditation.

**Opening scene.** Sunday evening. The Habbits URL is live. Kevin opens it on his laptop, sees a sign-up form. No marketing, no upsell — just email + password.

**Rising action.** He signs up, gets bounced into an empty habit list with an "Add habit" button. He types "Medicine" and hits enter. The habit appears in the list with an unchecked box and "Streak: 0." He adds the other four. Total elapsed: under two minutes.

**Climax.** He checks off "Medicine" for today. The box ticks; the streak number flips to **1**. He reloads the page. State persists.

**Resolution.** He pulls out his phone, opens the same URL, signs in. The five habits are there. He thinks: *this is enough. I can use this tomorrow.*

**Capabilities this journey requires:**

- Public sign-up form (email + password) and login form.
- Session-based auth that survives page reloads on web.
- Habit creation with a name field (only).
- Habit list view with current streak and today's checkbox per habit.
- Idempotent check-off endpoint (today only).
- Multi-device session: same account works on a second browser.

---

### Journey 2: Daily Check-Off (The Core Loop)

**Persona:** Kevin, now seven days in. The habit list is the first thing he looks at after taking his morning medicine.

**Opening scene.** 7:42 AM. Kevin pulls out his phone, opens the Habbits URL from a home-screen bookmark. He's already authenticated. The habit list loads in under two seconds.

**Rising action.** He sees five habits, each with: name, current streak (today's number depends on whether he's checked off), an unchecked checkbox for today. He taps the checkbox next to "Medicine." Optimistically, the box ticks and the streak number bumps. The request lands; no network spinner.

**Climax.** He sees that meditation is still unchecked from yesterday, and his streak there shows 0 (broken). He doesn't get to retroactively check yesterday — v1 doesn't allow it. He accepts that and moves on.

**Resolution.** He closes the phone. The whole interaction is under five seconds. Zero friction.

**Capabilities this journey requires:**

- Mobile-web responsive layout (one-handed tap target ≥ 44pt).
- Optimistic UI update on check-off.
- Streak number renders correctly relative to "today" in the user's timezone.
- A streak that broke yesterday is visible as "0" (not hidden, not "1").
- Today-only check-off semantics enforced on both client and server.

---

### Journey 3: "Okay, Gone" (The Differentiator)

**Persona:** Kevin, four weeks in. Decides "Reading" isn't sticking — it doesn't fit his current commute. In coach.me, he'd have abandoned it on the list and watched it accumulate guilt.

**Opening scene.** Kevin opens the habit list. "Reading" sits there with a 3-day streak that has stalled at 0 for the last week.

**Rising action.** He taps into the habit's detail (or a contextual menu). He sees a *Delete* button. He taps it. A confirmation prompt appears: "Delete *Reading* and all its check-offs? This cannot be undone."

**Climax.** He confirms. The habit disappears from the list. The check-off history is gone. The list now shows four habits instead of five. **Okay, gone.**

**Resolution.** No tombstone, no archive, no "you can restore this for 30 days." The data is destroyed. Kevin trusts the tool a little more — because he just proved to himself it'll let go when he asks.

**Capabilities this journey requires:**

- A Delete action on each habit, with a single confirmation step.
- Hard-delete semantics: habit row + all its check-off rows are removed from the database.
- The deleted habit does not reappear, is not soft-archived, has no "undo" affordance.
- Confirmation copy reflects the destructive semantics ("This cannot be undone").

---

### Journey 4: Broken Streak (Recovery / Edge Case)

**Persona:** Kevin, three months in. Travel + jet lag broke his medicine streak — he missed two days.

**Opening scene.** He opens the app post-travel. The streak on "Medicine" reads **0** (it was 47 before he left).

**Rising action.** A small flicker of regret. There is no UI to recover the streak — Habbits will not let him retroactively check off the two missed days. (This is a v1 product decision: retroactive check-off is post-MVP, intentionally.) The 30-day completion % reflects the dip honestly: ~93% instead of 100%.

**Climax.** Kevin checks off today's medicine. Streak resets to **1**. The completion % stays accurate.

**Resolution.** No shame moment, no "you broke your streak!" notification. The product simply renders the truth. Kevin keeps going — and the trust earned in Journey 3 carries forward: the tool didn't lie to him about his data.

**Capabilities this journey requires:**

- A missed day correctly resets the streak to 0 on the next view (computed, not stored).
- No automated "punish" messaging — no toast, modal, or push about broken streaks.
- 30-day completion % accurately reflects the dip without UI sugar-coating.
- No mechanism (UI or API) to retroactively check off prior dates in v1.

---

### Roles Not Present in v1 (and Why)

- **No admin role.** Each user manages only their own data. There is no organization, team, group, or moderation context.
- **No support role.** Support is the author for the author. If something breaks, it's a personal bug filed against the repo.
- **No API consumer role.** The HTTP JSON API exists, but is not publicly documented or designed for third-party clients in v1. CORS is non-existent (same-origin architecture) so external clients can't even reach it from a browser. OpenAPI spec and external-client support are post-MVP.
- **No moderator / content reviewer.** No user-generated content is shared between users.
- **No billing / subscription role.** Free-as-in-self-hosted; no payment flow.

These roles are *intentionally* absent. Adding any of them would expand v1 scope past the 1–3 week timeline without serving the personal-use success criteria.

### Journey Requirements Summary

Mapping each journey to the functional capability areas it implies (formalized as Functional Requirements below):

| Journey | Required Capability Areas |
|---|---|
| 1. First Habit | Sign-up, login, session persistence, habit creation, habit list view, check-off endpoint, multi-device session |
| 2. Daily Check-Off | Mobile-responsive layout, optimistic UI, timezone-correct streak rendering, today-only check-off enforcement |
| 3. "Okay, Gone" | Habit detail/action menu, delete action with confirmation, hard-delete cascade (habit + check-offs), no undo affordance |
| 4. Broken Streak | Computed-not-stored streak math, no automated punishment messaging, accurate 30-day completion %, no retroactive check-off |

**Out of journey coverage (deliberate):** account deletion, password change (since password reset is deferred), data export, mobile-native experience. These either belong to post-MVP or to administrative paths that v1 handles via direct DB access by the author.

## Web App Specific Requirements

### Project-Type Overview

Habbits v1 is a single-page web application built on React Native + Expo + `react-native-web` (TypeScript), served from a same-origin Go binary on Fly.io. The web target is the only frontend in v1; iOS and Android use the same codebase post-MVP via Expo's native build pipeline. There is no separate marketing site, public content, or landing page — authenticated experience only.

### Technical Architecture Considerations

- **Application style:** SPA. The Go binary serves the pre-built static bundle (HTML + JS + CSS) at the root path; all UI routes are client-side via Expo Router. The JSON API is mounted under `/api/...` on the same origin.
- **Render strategy:** Client-side rendering only. No SSR, no hydration, no SSG. Avoids the documented complexity of SSR + RN-Web.
- **Build pipeline:** `expo export --platform web` produces the static bundle. Output is committed to the deploy artifact (or built in CI and embedded into the Go binary via `embed.FS`).
- **Asset serving:** Static assets served by Go via `http.FileServer` over an embedded filesystem. Cache headers: immutable for hashed asset filenames, no-cache for `index.html`.
- **Routing:** Client-side routing for app paths; server-side catch-all that returns `index.html` for unknown non-`/api/*` paths to support deep-linked URLs.

### Browser Support Matrix

Modern evergreen browsers only. No legacy support; this is a personal tool.

| Browser | Support |
|---|---|
| Chrome / Chromium (last 2 stable versions) | Yes — primary desktop target |
| Safari (current + previous major, macOS + iOS) | Yes — primary mobile target |
| Firefox (last 2 stable versions) | Yes |
| Edge (Chromium-based, last 2 stable) | Yes — implicit via Chromium |
| Internet Explorer / legacy Edge / Opera Mini / UC | **Not supported.** No polyfills, no transpile fallbacks below ES2020. |

### Responsive Design

Mobile-first. The dominant daily-driver use case is "phone browser, one-handed, in under five seconds."

- **Breakpoints:** Single fluid layout from 320px upward. Optional desktop refinement at ≥768px (denser list view, sidebar nav).
- **Tap targets:** Minimum 44×44pt for any tappable element (checkboxes, delete buttons, action menus).
- **Input types:** `inputMode="email"` on email, `autoComplete` hints on auth fields, `enterKeyHint` on text fields where natural.
- **Viewport:** `<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">`. Safe-area-inset respected for iOS notch.
- **Orientation:** Portrait optimized; landscape works but is not designed-for.
- **No fixed pixel widths** in component layouts — flex-based throughout, since RN-Web's `StyleSheet` enforces this naturally.

### Performance Targets

Specified as binding requirements in `## Non-Functional Requirements → Performance` (NFR1–NFR5).

Additional non-binding guidance for this project type:

- Target Lighthouse Performance score (mobile) ≥ 85. Optional gate, not blocking CI.
- TTFB, INP, FID, and CLS are not measured as hard gates. The app is light enough (single screen, ~5 list items) that aggressive performance tuning is overkill.

### SEO Strategy

**Not applicable.** Habbits is an authenticated personal tool — no public content, no landing pages, no blog, no marketing surface.

- `index.html` includes `<meta name="robots" content="noindex,nofollow">`.
- `robots.txt` at root disallows all crawling.
- No sitemap, no structured data, no Open Graph tags (no shareable public URLs in v1).
- If a public-facing "About" or marketing page is added post-MVP, SEO strategy is reconsidered then.

### Accessibility Level

Pragmatic floor: the app does not fail basic screen-reader and keyboard navigation for the critical flow. No formal WCAG compliance level is pursued in v1.

**In scope for v1:** specified as NFR16–NFR19 in `## Non-Functional Requirements → Accessibility` (keyboard reachability, focus indicators, color contrast, semantic labels, VoiceOver smoke test of the critical flow).

**Out of scope for v1 (post-MVP if/when needed):**

- Formal WCAG AA or AAA conformance audit.
- Reduced-motion / high-contrast theme variants.
- Internationalization / RTL support.
- Voice-input alternative flows.

### Implementation Considerations

- **Time zone capture:** at sign-up, capture user timezone from browser (`Intl.DateTimeFormat().resolvedOptions().timeZone`) and store on the user record. User can override post-signup (post-MVP; v1 reads browser TZ on signup, no settings screen).
- **Offline behavior:** none. Habbits requires connectivity. A failed check-off shows an error toast; no queued retry, no IndexedDB cache. (Offline-first is post-MVP.)
- **State management:** TanStack Query for server-state (read-heavy, lightly-mutating). No Redux, no MobX, no global client-state library beyond React's built-in primitives.
- **Form handling:** native HTML form behavior + RN-Web `TextInput`. No react-hook-form / formik in v1 unless friction warrants.
- **Error boundaries:** one top-level React error boundary; on render error, render a "Something broke — reload" fallback that triggers a hard reload. No Sentry / error reporting in v1.
- **Analytics:** none in v1. Personal tool, no usage telemetry.

## Project Scoping & Phased Development

### MVP Strategy & Philosophy

**MVP Approach: Problem-Solving MVP.**

Habbits v1 exists to test a specific hypothesis: *a habit tracker that respects user data (mutable, hard-deletable, future-exportable) is one the user will trust enough to stick with.* The author has a real, recurring problem — coach.me's locked-after-creation habits — and the MVP exists to validate that the inversion changes adherence in his own life, on his own data.

- **Not an Experience MVP:** the UX is intentionally conventional. No novel interactions, no gesture mechanics, no visual innovation. Borrowed patterns (Apple-style streak counter, simple list view) are fine.
- **Not a Platform MVP:** no third-party developers, no plugin surface, no public API in v1.
- **Not a Revenue MVP:** no commercial intent. No payments, no subscriptions, no usage caps.

**Validated learning targets:**

1. *Does deletability change behavior?* — Does removing a stale habit increase willingness to add the next one? (Measured: how often the "okay, gone" interaction is exercised by month 3.)
2. *Is daily checkbox + streak + 30-day % sufficient for personal motivation?* — Or does the absence of richer analytics (heatmaps, weekday patterns) become a felt gap quickly?
3. *Does same-codebase web → mobile pay off?* — Validated by how quickly mobile parity ships post-v1.

### Resource Requirements

- **Team size:** 1 (the author).
- **Time budget:** 1–3 weeks of evening/weekend work.
- **Skills required:** Go (idiomatic), Postgres + SQL, TypeScript, React Native + Expo + react-native-web, GitHub Actions, Fly.io. None require deep specialization; all "competent and idiomatic" depth.
- **External dependencies:** Fly.io account, GitHub account, a domain name. No external service contracts (no email provider needed since password reset is deferred).
- **Recurring cost:** Fly.io compute + Postgres ≈ $5–10/month single-user. No other recurring spend.

### MVP Feature Set (Phase 1 — Week 1–3)

The complete MVP-in-scope feature list is owned by the `## Product Scope → MVP` section above. Cross-referenced here as the binding scope; not re-listed to avoid drift.

**Core user journeys supported in MVP:** all four documented journeys (First Habit, Daily Check-Off, "Okay, Gone", Broken Streak) — see `## User Journeys`.

### Post-MVP Features

The Growth (Phase 2) and Vision (Phase 3) feature ordering is owned by the `## Product Scope → Growth Features` and `## Product Scope → Vision` sections above. Phase boundaries:

- **Phase 2 (Growth):** ships after ≥7 consecutive days of MVP dogfooding. Order: CSV/JSON export → mobile parity → password reset → best-streak → heatmap → reminders → non-daily cadence → retroactive check-offs. Each is independently shippable.
- **Phase 3 (Vision):** self-hostable distribution, OSS positioning, lightweight accountability, richer analytics, quantity-based habits. No fixed sequence; pulled when warranted.

**Phase gates (binding):**

- No Phase 2 feature lands before 7 consecutive dogfooding days on the v1 MVP.
- Reminders (Phase 2 item) does not land until at least one of mobile parity OR password reset has shipped — they share infrastructure (Expo Push / email-adjacent tooling).

### Risk Mitigation Strategy

#### Technical Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Streak math wrong across timezones / DST | High — most common habit-tracker bug class | Table-driven Go test crossing DST boundaries in ≥2 timezones; "today" computed from user-TZ on user record |
| RN + Expo + `react-native-web` setup yak shave > 2 days | Medium | Kill criterion authorized: drop to plain React + Vite for web, accept divergent mobile codebase later |
| Auth complexity (cookie sessions, CSRF, argon2id) slips past week 2 | Medium | Kill criterion authorized: drop to single-user hardcoded account; defer real auth to Phase 2 |
| Postgres / Fly.io deploy yak shave at integration time | Medium | Deploy hello-world Go binary on Day 1 before any feature code; kills the deploy yak shave first |
| Migration tooling bikeshed (goose vs migrate vs atlas) | Low | Pre-committed to `goose`; do not revisit |
| `chi` vs `net/http` middleware sprawl | Low | Pre-committed to chi + three middlewares only (recoverer, request-id, auth); resist adding more |
| Same-origin CORS regression if architecture changes | Low | Bound by architectural rule: Go binary serves API + SPA from one origin |

#### Market / Adoption Risks

This product has no market in the commercial sense. Adoption risk is reframed as: *does the author actually replace coach.me with this?*

| Risk | Mitigation |
|---|---|
| Day 7 dogfood target slips | If slipping by > 3 days, cut a feature — do not extend timeline |
| Starting from zero streaks demotivates the author into not switching | Accept as cost of v1; no coach.me import in scope (post-MVP backlog placeholder) |
| Author finds the absence of heatmap / analytics motivationally lacking | Phase 2 heatmap and best-streak items are pre-ordered for fast-follow |
| Feature creep ("this would be almost free") mid-sprint | Pre-authorized hard rule: nothing from the "out of scope" list lands before 7 consecutive dogfooding days |

#### Resource Risks

| Risk | Mitigation |
|---|---|
| Available time < 1 week effective due to life | Kill criteria above; if real time drops below 1 week, cut to single-user + plain React + SQLite to ship |
| Burnout from full-cycle ambition | "Just get working" depth target across all slices — no specialization. Reviewer noted "competent and idiomatic" has no stop condition; explicit ceiling on each slice in `## Success Criteria → Project Success` |
| Solo work means no review partner for risky decisions | Capture deferred decisions as ADRs in `docs/adr/` (optional, per opportunity reviewer; flagged but not committed) |

## Functional Requirements

The following are the binding capability contract for Habbits v1. Any capability not listed here is out of scope. Each FR is testable, implementation-agnostic, and traces back to a journey, scope item, or success criterion documented above.

### Account Management

- **FR1:** A visitor can create a new account by providing an email address and a password.
- **FR2:** A visitor can sign in to an existing account using their email and password.
- **FR3:** An authenticated user can sign out of their account, ending the active session.
- **FR4:** A signed-in user's session persists across page reloads and browser restarts (until expiration or explicit sign-out).
- **FR5:** A user can be signed in to the same account from multiple devices or browsers simultaneously, with each device sharing the same view of their data.
- **FR6:** The system captures and stores the user's local timezone at account creation, and uses it as the authoritative timezone for all date computations for that user.
- **FR7:** The system stores user passwords in a form that cannot be reversed to recover the original password.
- **FR8:** The system prevents account creation with an email address already associated with an existing account.

### Habit Management

- **FR9:** A signed-in user can create a new habit by providing a habit name.
- **FR10:** A signed-in user can rename an existing habit they own.
- **FR11:** A signed-in user can permanently delete a habit they own, including all of its associated check-off history.
- **FR12:** The system requires explicit user confirmation before performing a habit deletion, and the confirmation copy communicates that the action is permanent and irreversible.
- **FR13:** Once a habit is deleted, the system provides no mechanism (UI or API) to restore the habit or its check-offs.
- **FR14:** A signed-in user can view a list of all habits they own.
- **FR15:** A user can only view, modify, or delete habits associated with their own account.

### Daily Check-Off

- **FR16:** A signed-in user can mark a habit they own as completed for the current day.
- **FR17:** The system treats "the current day" as the user's local calendar date in their stored timezone.
- **FR18:** The system permits at most one check-off per habit per local day; a duplicate check-off for the same day is accepted but produces no additional state change.
- **FR19:** The system does not provide any mechanism for a user to record a check-off on a date other than the current local day.
- **FR20:** The system reflects a successful check-off in the user interface without requiring a full page reload.

### Progress Visibility

- **FR21:** For each habit, the system displays the user's current consecutive-day streak, computed as the count of consecutive prior local days (including today, if checked) on which the habit was completed.
- **FR22:** A streak displays as zero when the user has missed one or more days, including when the most recent check-off is two or more days in the past.
- **FR23:** For each habit, the system displays the user's rolling 30-day completion percentage, defined as the number of completed days divided by the number of days since habit creation, capped at 30, excluding the current day when not yet checked.
- **FR24:** Streak and completion-percentage values are computed from check-off history rather than stored as denormalized counters.
- **FR25:** The system does not display, send, or surface any automated messaging (notification, modal, toast, or banner) that highlights, criticizes, or penalizes a broken streak.

### Cross-Device Access

- **FR26:** The product's interface is usable on a mobile-phone browser in portrait orientation with single-handed touch interaction.
- **FR27:** All interactive elements (controls for check-off, deletion, account actions) are large enough to be reliably activated by touch on a mobile device.
- **FR28:** The product's interface is usable on a desktop browser via mouse and keyboard, with all interactive elements reachable by keyboard navigation in a logical tab order.

### System Behavior

- **FR29:** The system restricts CRUD operations on habits, check-offs, and account state to authenticated users only; unauthenticated requests are rejected.
- **FR30:** The system protects state-changing requests (create, modify, delete, check-off) from being executed on behalf of a user without that user's intent (i.e., cross-site request forgery is prevented).
- **FR31:** When the user interface encounters an unrecoverable rendering error, the system presents the user with a clear path to recover (such as a reload action) rather than displaying a broken state silently.
- **FR32:** The system rejects any request from a user to access, modify, or delete a habit or check-off owned by another user.

## Non-Functional Requirements

NFRs specify quality attributes — how well the system performs — and complement the binding capabilities in Functional Requirements. Categories that do not apply to v1 (Scalability, Integration) are intentionally omitted.

### Performance

- **NFR1:** First Contentful Paint on mobile web under 4G-simulated network conditions completes in under 2.0 seconds (measured with Chrome DevTools throttling, no cache).
- **NFR2:** Time to Interactive on mobile web under 4G-simulated network conditions completes in under 3.5 seconds.
- **NFR3:** The habit-list endpoint (authenticated user, up to 5 habits, including computed streaks and completion percentages) responds at a median latency under 100 ms when measured against a single-region Fly.io deployment with co-located Postgres.
- **NFR4:** The check-off endpoint responds at a median latency under 80 ms under the same conditions.
- **NFR5:** Initial JavaScript bundle (gzipped) is at most 350 KB.

### Security

- **NFR6:** User passwords are stored using a memory-hard password-hashing function suitable for credential storage (e.g., `argon2id` with current OWASP-recommended parameters). Plaintext storage and unsalted fast-hash storage (MD5, SHA-1, SHA-256) are forbidden.
- **NFR7:** Session identifiers are transmitted to clients exclusively via cookies marked `HttpOnly`, `Secure`, and with `SameSite=Lax` (or stricter).
- **NFR8:** All state-changing endpoints require a valid CSRF defense (synchronizer-token, double-submit-cookie, or framework-equivalent) and reject requests that fail validation.
- **NFR9:** Sessions expire after a defined inactivity period (target: 30 days idle) and on explicit sign-out, after which the credential is unusable.
- **NFR10:** Request and response logs redact authentication payloads (passwords, session tokens, CSRF tokens) and any field marked sensitive; no such field appears in plaintext in any log destination.
- **NFR11:** All traffic between client and server is served exclusively over TLS (HTTPS). The deployed environment redirects HTTP to HTTPS and serves valid certificates.
- **NFR12:** Authorization is enforced server-side for every resource access: a user can never access, modify, or delete data owned by another user, even via direct API request manipulation. (Capability mirror: FR15, FR32.)

### Reliability

- **NFR13:** The product has no formal availability SLA. Brief downtime during deploys is acceptable. A successful deploy from `main` should complete with under 30 seconds of unavailability for in-flight users.
- **NFR14:** Application panics in the Go process do not crash the server; a panic-recovery middleware catches them, logs the stack trace with a request ID, and returns a generic 500 response to the client.
- **NFR15:** A failed database query in any single request does not corrupt persistent state. Multi-step state changes (e.g., habit deletion with cascading check-off removal) execute within a single database transaction.

### Accessibility

- **NFR16:** All interactive elements are reachable and activatable via keyboard alone, with a visible focus indicator on every focusable element.
- **NFR17:** Text content meets a minimum color contrast ratio of 4.5:1 against its background (WCAG AA equivalent).
- **NFR18:** Form inputs are associated with semantic labels (HTML `<label for>` or accessible-name equivalent); icon-only buttons carry an `aria-label` describing their action.
- **NFR19:** The critical end-to-end flow (sign-up → create habit → check off → see streak) is operable via VoiceOver on iOS Safari without dead ends or unlabeled controls.

### Privacy

- **NFR20:** The system collects only the data required to operate: email, password (hashed), timezone, and habit/check-off records. No usage telemetry, behavioral analytics, or third-party trackers are present in v1.
- **NFR21:** Hard deletion of a habit (FR11) removes all associated check-off records from persistent storage; no copy, backup, soft-delete tombstone, or shadow record persists beyond the next routine database backup cycle. Backup retention policy is documented in operational notes.

### Maintainability & Observability

- **NFR22:** All application logs are emitted as structured key-value records (JSON or `slog`-formatted), to enable downstream filtering and querying without parsing free-form text.
- **NFR23:** Every HTTP request is assigned a unique request ID at ingress; the request ID appears in every log line emitted while handling that request, and is returned to the client in a response header for correlation.
- **NFR24:** The full database schema is reconstructible from versioned migrations checked into the repository, runnable from an empty database with a single command.
- **NFR25:** The build is reproducible from a clean checkout: `git clone` + a documented command sequence (target: under 5 distinct commands) produces a deployable artifact.

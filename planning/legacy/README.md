# bmad-legacy — frozen reference

These documents are **archived, read-only references** from the original
BMad-era plan for Habbits, when it was a **web-first Go + Postgres backend**
project. That approach was abandoned in June 2026 in favor of a
**cross-platform, local-first mobile app with no backend** (Flutter, on-device
SQLite, open source).

**Status of the surviving files:**

- `product-brief-habbits.md`, `product-brief-habbits-distillate.md`, `prd.md` —
  their **product layer** (the "okay, gone" data-ownership thesis, the five real
  habits, streak / completion-% rules, competitive intel) was **distilled into the
  current spec** and remains valid. Their **technical layer** (Go, `chi`, Postgres,
  `goose`, cookie-session auth, CSRF, Fly.io, React Native + Expo web) is **dead** —
  ignore it.

**Current source of truth:**
`docs/superpowers/specs/2026-06-13-habbits-mobile-local-first-design.md`.

Deleted (not archived) as fully obsolete: the Go backend code, the foundation
spec, the day-1-deploy spec + plan, the original `architecture.md`, and the
BMad→Superpowers migration docs. Git history retains them.

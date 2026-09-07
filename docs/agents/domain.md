# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the
codebase. This repo is **single-context**.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root: what this repo is, and the glossary.
- **`docs/adr/`**: read the decision records that touch the area you're about to work in.

If any of these files don't exist, **proceed silently**. Don't flag their absence; don't suggest
creating them upfront. The `/domain-modeling` skill creates them lazily when terms or decisions
actually get resolved.

## File structure

```
/
├── CONTEXT.md
├── docs/adr/
│   ├── 0001-….md
│   └── 0002-….md
├── lib/            ← the source; ui/, domain/, data/
└── test/           ← mirrors lib/
```

There is no `CONTEXT-MAP.md` and no per-package `CONTEXT.md`: one repo, one context. There is
also no `architecture/` and no `planning/` — the present is the source, and what must stay true
is a test whose name is the claim and whose comment opens `INVARIANT:`.

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a proposal, a hypothesis, a test
name), use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary explicitly
avoids: write `Habbits` for the app and `habit` for the thing it tracks, and reserve `sync` for
recomputing scheduled reminders — this app moves no data off the device.

If the concept you need isn't in the glossary yet, that's a signal: either you're inventing
language the project doesn't use (reconsider) or there's a real gap (note it for
`/domain-modeling`).

## Link style inside `docs/`

`docs/` is read on GitHub. Between files inside `docs/`, use a plain relative `.md` link — from
one ADR to another, that is `[ADR-NNNN](NNNN-slug.md)`. Paths outside `docs/` are cited as
inline code rather than linked, so a file move cannot silently break a rendered link.

## Flag ADR conflicts

If your output contradicts an existing decision record, surface it explicitly rather than
silently overriding:

> _Contradicts ADR-NNNN (its title), but worth reopening because…_

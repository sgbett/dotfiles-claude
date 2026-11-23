# Non-code projects in /opt/claude

Most folders here are research, study, case files and personal records, not software. These conventions apply to them. A code project (e.g. `cabinet`) follows the global rules and ignores this file.

Before setting up or reorganising a non-code project, pick its archetype below, lay down the shared skeleton, then add only that archetype's variations.

This file is `~/.claude/docs/personal-projects.md` in the dotfiles repo; `/opt/claude/CLAUDE.md` is a symlink to it. Edit it there, in place.

## Core rules

1. **Steer in prose.** A short CLAUDE.md and a clear layout do the work. No custom agents, MCP servers, vaults, indexes or pipelines until a real question can't be answered without one — then check it actually gets used. `rcpsych-intel` retired its whole January build-out because it didn't.
2. **README says what and why; CLAUDE.md says how.** README: the question or goal, status, a layout table. CLAUDE.md: operational rules only, ideally under 60 lines.
3. **Material moves one way:** `inbox/` → `sources/` → working files → `out/`. Sources are never edited. Working files are amended in place — git holds the history, so no `_v2`, `_prev` or `copy` files. Anything that has left the machine is frozen; corrections go in errata.
4. **One hub, one operative record per topic.** A single hub file gives the current picture; other files point to records rather than re-summarise them. Superseded files move to `archive/`.
5. **Label every claim by its source.** Each project's CLAUDE.md defines its label set (e.g. quote · observed · measured · inference · recollection · unverified). Record negative results too.
6. **Record first.** Check the written record before asking me to remember.
7. **Settled is settled.** Decisions, non-goals and out-of-scope items live in CLAUDE.md with their reasons; if a request would break one, say so rather than work round it. Keep an "Errors made before" list and check it.
8. **Outbound gate.** CLAUDE.md states what may leave the machine and to whom; nothing else leaves without my explicit go.
9. **Structure arrives with the second need.** Start from the skeleton; add a folder, file type or tool when a second instance needs it, not before.

## Skeleton

```
<project>/
├── README.md              question or goal · status · layout table
├── CLAUDE.md              sections below
├── inbox/                 untriaged drops (scans, exports, downloads)
├── sources/               never edited; INDEX.md; HASHES.txt (SHA-256) for large files kept out of git
├── <working files>        per archetype; one hub
├── out/YYYY-MM-DD_slug/   anything that leaves; frozen once sent
└── archive/               superseded material, kept not deleted
```

- Create folders when first needed, not up front.
- Local git from day one, committing straight to `master`. Sensitive projects have no remote; raw sensitive material goes in a gitignored `local/`.
- Date-prefix anything dated (`YYYY-MM-DD_slug`) so the newest sorts last.
- A plan (`.claude/plans/YYYYMMDD-slug.md`, Status line at the top) only for multi-phase work; it is then the spec.

**CLAUDE.md sections:** What this is (one line, pointing to README) · Handling rules (outbound gate, whose data may be read, claim labels) · Layout and flow · Conventions · Errors made before.

## Archetypes

| Archetype | Centred on | Working files | Reference projects |
|---|---|---|---|
| Case file | evidence | `analysis/SYNTHESIS.md` hub + spokes (chronology, register); `correspondence/YYYY-MM-DD_slug/` | `the-land`, `sarah` (template), `rcpsych-intel` |
| Study | a question | `ideas.md`, `reading-list.md`, `references.bib`, a skeleton deliverable | `ma-philosophy`, `hand-rolled-secp256k1-lit-review`, `tma05` |
| Dossier | decisions | `VISION.md`, `open-questions.md`; locked decisions in CLAUDE.md | `amanuensimus`, `sgbett-com`, `bsv-wallet-ex` |
| Life area *(provisional)* | state over time | `STATUS.md` hub; `log/YYYY-MM-DD_slug.md` | `opsec`, `health` |

**Case file** — sources hashed on intake, each intake with a triage README (provenance, duplicates, new facts with sources). Every party's statements, mine included, are evidence, not conclusions. Machine output is labelled as such; gaps are marked (`[illegible]`), never filled. A heavy exhibit gets its own satellite project that reads from the case file but never writes to it (`bun-fight`).

**Study** — cite only what is checked against a primary record; anything else is marked **unverified**. Reading-list notes say why a work matters *here*. For rigour, extract before synthesising and run each critical phase in a fresh session (`hand-rolled-secp256k1-lit-review/prompts/`). Coursework is a Study with the brief and set texts converted to text in `sources/`.

**Dossier** — documents before build: no code until the vision and decisions settle. Non-goals carry reasons. Explorations are archived and labelled as sketches, not deleted.

**Life area** *(provisional — confirm or revise once `health` has run for a while)* — `STATUS.md` is overwritten with the current picture; `log/` is dated and append-only. Labels distinguish measured (device or connector data), self-reported, clinician-said, read and inference. Data pulled from connectors lands in `sources/` with its pull date. Nothing personal leaves.

## Adding an archetype

A project that fits none of these runs on the core rules and skeleton alone. When a second project needs the same variation, add a row and a paragraph here. Provisional rows are confirmed or removed once tried.

## Don't

- Bring software machinery to non-code work — pipelines, schemas, ADRs, RAG (`rcpsych-intel`, January 2026).
- Keep drafts as copies instead of in git (`ema`, `stylometry`).
- Scaffold with nothing behind it (`support-responder`).
- Leave superseded files at the root (`the-land`).
- Keep secrets in plain files (`coins`).

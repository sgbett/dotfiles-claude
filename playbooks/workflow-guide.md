# Workflow Guide

How work moves from idea to merged change.

## The flow

1. **HLR issue** frames the *why* — problem, outcome, acceptance criteria (see `~/.claude/profiles/work-organisation.md`).
2. **A plan, only when warranted.** For work with real design choices, a plan emerges organically — sometimes before the HLR, sometimes after. If one exists, the **HLR references it** (link the plan path from the issue) and the plan's header names the issue (e.g. `Tracking: #N`). No plan is needed for bounded, obvious work.
3. **`/do <issue>` takes over.** It follows the project's own conventions, decides full path vs lean off-ramp, and breaks the work into line items — a sub-issue only for an item big enough to need its own breakdown. It builds, QAs, runs the security gate when warranted, and opens the PR. Running it is the approval; it stops to ask only when a call isn't clear-cut.

Small issues take `/do`'s lean path (no specialist panel, QA inline); the ledger, security gate and PR still apply. A trivial change with no issue behind it needs only branch → implement → PR.

## Where plans live

| Location | When | Naming |
|----------|------|--------|
| `~/.claude/plans/` | scratch / not yet tied to an issue | auto or kebab-case |
| `<project>/.claude/plans/` | linked to a GitHub issue | date-prefixed, e.g. `20260215-thing.md` |
| `~/.claude/playbooks/` | a distilled, reusable procedure | descriptive kebab-case |

In the dotfiles repo itself, `plans/` is gitignored scratch; tracked docs go in `docs/`.

## Promoting a plan to a playbook

When a completed plan proves stable and reusable, distil it to actionable steps in `~/.claude/playbooks/<name>.md`, leaving out the research and rationale, and link the playbook back to the plan. The original stays where it is: plans are project artefacts and part of the record.

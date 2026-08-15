# Workflow Guide

How work moves from idea to merged change.

## The flow

1. **HLR issue** frames the *why* — problem, outcome, acceptance criteria (see the HLR section in `~/.claude/CLAUDE.md`).
2. **A plan, only when warranted.** For work with real design choices, a plan emerges organically — sometimes before the HLR, sometimes after. If one exists, the **HLR references it** (link the plan path from the issue). No plan is needed for bounded, obvious work.
3. **`/do-hlr <issue>` takes over.** The skill decides full-team vs lean off-ramp, breaks the HLR into sub-issues, builds, QAs, runs the security gate when warranted, and opens the PR. You stay in the loop at each gate.

Small, obvious changes skip all of this: branch → implement → PR.

## Where plans live

| Location | When | Naming |
|----------|------|--------|
| `~/.claude/plans/` | scratch / not yet tied to an issue | auto or kebab-case |
| `<project>/.claude/plans/` | linked to a GitHub issue | date-prefixed, e.g. `20260215-thing.md` |
| `~/.claude/playbooks/` | a distilled, reusable procedure | descriptive kebab-case |

In the dotfiles repo itself, `plans/` is gitignored scratch; tracked docs go in `docs/`.

## Promoting a plan to a playbook

When a completed plan proves stable and reusable, distil it to actionable steps in `~/.claude/playbooks/<name>.md`, drop the research/rationale, and delete or archive the original.

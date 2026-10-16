<!-- profiles/work-organisation.md — portable issue and PR practice -->

# Work organisation

How work is organised on GitHub so the issue tracker makes sense at a glance — safe to adopt standalone. Imported by a global or project `CLAUDE.md`. No dependency on private skills or paths.

- **One ticket per area.** Related problems in one area go in one issue with a checklist of line items — "three minor import fixes" is one issue with three items, not three issues that reference each other. Before filing, look for an open issue covering the area and add to it.
- **Sub-issues only for big items.** An item gets its own sub-issue only when it's big enough to need its own breakdown. GitHub's sub-issue link is the only hierarchy — never write `Parent: #N` or "Part of #N" into a body.
- **Edit issues in place.** Correct an issue by editing it; never close and recreate one that's in flight — someone may already be working against it, and a replacement breaks references. A new issue is for genuinely new work.
- **Fix inline over filing follow-ups.** Fix a defect found during a PR — raised by a reviewer, or a cheap pre-existing one in code the PR touches — in that PR. File a follow-up only when the fix is substantial (new design, cross-cutting change, large scope).
- **Out-of-scope fixes are recorded, not silent.** Changes stay within the stated objective; an opportunistic fix beyond it becomes a line item on the issue, so the widened scope is visible in the record.

## HLR (High-Level Requirement) issues

An HLR is a GitHub issue that captures the *why* before implementation: the problem and the outcome. Create one for work that needs explicit acceptance criteria, a feature whose problem and solution need articulating, or work likely to spawn several tasks.

Capture:
- **Problem:** what's wrong, missing or needed
- **Approach:** high-level direction, not implementation detail
- **Acceptance criteria:** how we'll know it's done (where inferrable)
- **Context:** related issues, discussions, background

Label `project:hlr`; title prefix `[HLR] ` (e.g. `[HLR] Implement incremental analysis capability`).

**Sub-issues don't inherit closure.** GitHub's sub-issue link (GraphQL `addSubIssue`) doesn't propagate closing, so the PR needs its own `Closes #N` for each sub-issue as well as the parent.

---
name: do-hlr
description: Execute a GitHub HLR (High-Level Requirement) issue end to end — first-cut breakdown, specialist co-production and synthesis, /plan:tasks → sub-issues, parallel build, QA verification, security gate, and PR. Use when the user runs `/do-hlr <issue#>` or asks to implement/execute an HLR. Runs the full pipeline for substantial HLRs and a lean path for small ones.
---

# Execute HLR

Take a GitHub HLR issue from issue to a merge-ready PR, orchestrated by **you (the lead)** with specialist sub-agents.

**HLR issue:** `$ARGUMENTS`

## Roles

- **Lead (you, this session)** — orchestrate the whole pipeline: pre-flight, the first-cut breakdown, synthesising specialist input, creating sub-issues (via `/plan:tasks`), and the final PR. You already hold the context — do **not** delegate orchestration or record-keeping to a sub-agent.
- **Specialist roster** — co-produce/augment the breakdown, each from one lens (security, performance, database, …). Sourced from the project's `.architecture/members.yml`, else this skill's bundled `assets/members.yml`.
- **Developers** — implement one sub-issue each, commit per task.
- **QA** — verify each acceptance criterion against the delivered code and tick the boxes (the step that gets missed).
- **White-hat** — security gate, conditional on what was touched.

## Pipeline

### 0. Pre-flight (lead)

1. Fetch the HLR: `gh issue view $ARGUMENTS`.
2. Resolve the base branch (PR target): if the HLR body has `Parent: #NNN` and a `feat/NNN-*` branch exists, base on it (sub-HLR work accumulates on the parent); otherwise base on `master`.
3. Verify the working tree is clean (`git status`); if dirty, stop and report.
4. Create/checkout the feature branch `feat/$ARGUMENTS-<slug>` from the resolved base.
5. **Plan-first commit.** If a plan file exists at `.claude/plans/YYYYMMDD-$ARGUMENTS-<slug>.md` (or any plan matching this HLR number), commit it as the first commit on the feature branch, together with any foundational docs the HLR establishes (ADRs, reference docs). Title: `docs(plans): #$ARGUMENTS — <HLR title>`. This anchors everything that follows; the plan is the durable input to step 1, and the PR's history shows the intent before any code. If no plan file exists, that's fine — the breakdown is born in step 1 as an HLR comment instead.
6. Give a one-line summary of the HLR + resolved base, then continue — no approval gate; the user approved by running the command.

### 1. First cut (lead)

Produce an ad-hoc breakdown of the HLR into candidate sub-tasks — independently implementable units, each with scope and acceptance criteria — drawing on the HLR body and the plan file (if one was committed in step 0) as primary input. **Post it as a comment on the HLR** as the durable record.

**Path selection.** The full pipeline is the default. The lean off-ramp — skipping specialist co-production and sub-issuing, doing QA inline — fits HLRs the first-cut analysis scopes as genuinely small: bounded change, no architectural choices, no security surface, one or two tasks at most. Examples: a typo, a single-file rename, a contained bug fix in well-understood code, a small additive change with obvious acceptance.

Use judgement. Clearly trivial → off-ramp; note what you skipped and why, then proceed. Clearly substantial → full path; don't ask. In between → analyse it (read the HLR, scan the touched code, weigh blast radius and security surface) and make the call. If anything makes you reach — cross-module impact, ambiguous acceptance, anything security-adjacent — default to the full path. Only stop to ask when the call isn't clear-cut after analysing — roughly, when you wouldn't bet 4:1 on it.

"Lean off-ramp" means *take* the off-ramp when an HLR is lean; it does not mean lean toward off-ramping by default.

### 2. Specialist co-production (full path)

Load the roster: prefer `<project>/.architecture/members.yml`; fall back to this skill's `assets/members.yml`. If neither exists, skip this phase and proceed lead-only (note it).

Spawn **one sub-agent per member, in parallel**, each given the HLR, the first-cut breakdown, and read access to the codebase, and asked to **augment the breakdown from its lens** — add missing tasks, flag risks, add concrete test scenarios/vectors, note edge cases. A member with nothing to add from its lens says so; that's expected and cheap.

**Always include the Pragmatic Enforcer, but treat it as advisory, not a veto.** It flags possible over-engineering; it does not get to remove scope on its own. In synthesis, drop or defer an item only if the enforcer flags it **and** no domain specialist defends it as load-bearing. Surface genuine conflicts to the user rather than letting the enforcer amputate real scope.

**Synthesise (lead):** merge the augmentations into a refined breakdown, filtering over-reach, then **update the HLR comment** to the synthesised breakdown.

### 3. Tasks → sub-issues (lead)

Run `/plan:tasks` to turn the refined breakdown into GitHub sub-issues linked to the HLR. **Hand `/plan:tasks` the synthesised breakdown explicitly** rather than relying on it inferring from the comment — the updated comment is the record, the passed breakdown is the input. Each sub-issue carries its acceptance criteria, edge cases, and test scenarios, and is linked to the HLR as a parent (GraphQL `addSubIssue`).

### 4. Build (developers)

Spawn a developer sub-agent per sub-issue — parallel for independent tasks, sequential where there are dependencies. Each developer:

1. Reads its sub-issue and the relevant existing code.
2. Implements clean, idiomatic, tested code.
3. Runs the project's linter on changed files; fixes offences.
4. Runs the relevant tests (targeted or full suite as appropriate).
5. **Commits** — stage by name (not `git add -A`), a Conventional Commit referencing the sub-issue (e.g. `feat: add X (#NN)`).
6. Reports completion. Blockers go as a comment on the sub-issue — never a silent work-around.

### 5. QA

Spawn a QA sub-agent (or do it yourself on the lean path) to **verify, not assume**:

- Check each acceptance criterion against the actual implementation — not "something was done".
- Run the test suite and linter; confirm green.
- Confirm docs were updated if public API surface changed.
- **Tick the acceptance boxes** on each sub-issue and close it with a brief completion note referencing the commit. This is the step that habitually gets missed — do not skip it.

### 6. Security gate (conditional)

If committed files match security-sensitive patterns (crypto / key / signature / BEEF / merkle / interpreter / `operations/`), run the security review — `Skill(skill: "security-review")` or the white-hat agent. Report Critical/High findings before the PR is considered ready. If nothing matches, skip.

### 7. PR (lead)

Push the feature branch (`-u`). Open a PR against the resolved base branch with a Summary + Test plan, and `Closes #$ARGUMENTS` plus a `Closes #<n>` for **each** sub-issue (sub-issue links don't propagate closure — each needs its own `Closes`). Report the PR URL.

## Sub-agents

Spawn sub-agents with the `Agent` tool — parallel calls in one message for independent work. Most are one-shot: they do their task and return. Developers report blockers via GitHub issue comments (durable, no live messaging needed), so no persistent team is required. If a sub-agent is unreachable or fails, **you (the lead) take over its work directly** — never block the pipeline on a dead agent.

## Notes

- **British English** in commits, comments, and docs; code identifiers follow the project's convention (American where a spec mandates it).
- **All work via PR**; no force-push, no `git revert`, never skip hooks.
- **Idempotent / resumable** — re-running skips closed sub-issues and continues from the next open one.
- **Green CI / tests are a hard gate** — don't open the PR (or mark it ready) on red.

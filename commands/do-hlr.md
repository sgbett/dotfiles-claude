# Execute HLR (High-Level Requirement)

Orchestrate an agent team to implement all sub-tasks of a GitHub HLR issue.

**HLR Issue:** $ARGUMENTS

## Overview

This command uses three specialist agents in a phased pipeline:

1. **Pre-flight** — Team lead fetches the HLR, verifies clean state, creates feature branch
2. **Prep phase** — PM ensures we're ready; Analyst researches and proposes task breakdown
3. **Plan phase** — PM creates sub-issues from analyst's breakdown
4. **Build phase** — Developer(s) implement, guided by analyst output
5. **Wrap phase** — PM verifies, commits, closes issues, creates PR
6. **Security gate** (optional) — White Hat audits before merge

Idle agents cost zero tokens. All agents stay alive throughout the pipeline.
The analyst's primary value is front-loaded (prep/plan phases), but observing the
implementation builds the analyst's memory for future HLRs — the learning flows
both ways.

---

## Pre-Flight (Team Lead)

Before spawning any agents, the team lead (you) does lightweight setup:

1. **Fetch the HLR**:
   ```bash
   gh issue view $ARGUMENTS
   ```

2. **Verify working tree is clean** (`git status`). If dirty, stash or abort.

3. **Create/checkout feature branch**: `feature/$ARGUMENTS-<slug>` from `master`.

4. **Present the HLR to user** with a brief summary and wait for approval
   to spawn agents.

---

## Phase 1: Prep (Parallel)

Spawn the **project-manager** and **technical-analyst** as teammates.

### Project Manager — Task 1: Verify Readiness
- Verify feature branch exists and is clean
- Check for any existing sub-issues on the HLR (may be a re-run)
- Confirm no blockers (dependency issues, missing prerequisites)
- Report readiness status

### Technical Analyst — Task 2: Analyse & Propose Breakdown
- Read the HLR description and acceptance criteria
- Read the existing codebase to understand what's already there
- Analyse the work required and propose a task breakdown:
  - Each task should be independently implementable and testable
  - Identify which tasks can be parallelised vs which must be sequential
  - For each task, specify:
    - Clear scope and acceptance criteria
    - Edge cases the developer must handle
    - Specific test scenarios (concrete, not vague)
    - Static test vectors for compatibility where applicable
  - Flag any discrepancies between the HLR spec and reality
- Comment the proposed breakdown on the HLR issue for permanent record

**Gate:** Both tasks must complete before Phase 2 begins.

---

## Phase 2: Plan (PM)

### Project Manager — Task 3: Create Sub-Issues
- Review the analyst's proposed task breakdown
- Create GitHub sub-issues for each task, linked to the HLR as parent:
  - Concrete acceptance criteria (from analyst's proposal)
  - Edge cases and test scenarios (from analyst's research)
  - Any test vectors or reference notes from the analyst
- Use the GraphQL API to create parent-child relationships
- Identify parallelisation opportunities from the analyst's breakdown
- Report the final task list to team lead:
  ```
  HLR #$ARGUMENTS: [Title]

  Sequential tasks:
  1. #201 - [Foundation task]
  2. #202 - [Depends on #201]

  Parallel tasks (after #202):
  3a. #203 - [Independent task A]
  3b. #204 - [Independent task B]

  Final task:
  4. #205 - [Integration/cleanup, depends on #203 and #204]

  Security gate: [yes/no]
  ```

**Gate:** Team lead reviews the task list and approves before Phase 3.

---

## Phase 3: Build (Developer(s))

Spawn **developer** agent(s) as teammates.

For sequential tasks, create one task per sub-issue, chained in dependency order.
For parallelisable tasks, spawn multiple developers working concurrently on
independent sub-issues.

Each developer receives:
- The sub-issue description and acceptance criteria
- The analyst's guidance (via GitHub issue comments)

### For each sub-issue, the developer:
1. Reads the issue and analyst's guidance comments
2. Reads relevant existing code in the project
3. Implements the solution — clean, tested, idiomatic code
4. Runs the project's linter on changed files, fixes offences
5. Runs the project's test suite (targeted or full suite as appropriate)
6. Marks the task complete

### Developer ground rules:
- **Ad-hoc scripts** go to `/tmp/` files, not inline one-liners
- **Discrepancies** between requirements and reality get commented on the
  relevant GitHub issue — not messaged to teammates

**Important:** Do not manually nudge agents. Let the task dependency system drive
the flow. When the developer(s) mark their final tasks complete, the PM's wrap-up
task automatically unblocks.

---

## Phase 4: Wrap (PM)

The PM's wrap-up task depends on all developer tasks completing.

### Project Manager — Final Task: Verify & Ship
1. **Verify acceptance criteria** — actually check each criterion against the code:
   - Read the implementation
   - Confirm tests exist and pass (run the project's test suite)
   - Confirm linter passes (run the project's linter)
   - Check that implementation matches specification, not just "something was done"
2. **Commit** — stage relevant files (not `git add -A`), conventional commit messages.
   Use judgement on granularity: one commit per HLR for cohesive features, or
   per-task commits when sub-tasks are independently meaningful. Either way,
   use conventional commit format and reference relevant issue numbers.
3. **Close sub-issues** with brief completion comments
4. **Create PR** against `master` with:
   ```
   ## Summary
   - [bullet points summarising what was implemented]

   ## Test plan
   - [ ] All tests pass
   - [ ] Linter clean
   - [ ] Acceptance criteria verified

   Closes #$ARGUMENTS
   ```
5. **Report** final status to team lead

---

## Phase 5: Security Gate (Optional)

If the HLR touches cryptographic code, key handling, signature operations, or
deserialisation of untrusted data, spawn the **white-hat** agent to audit the
PR diff before merge.

The white-hat operates globally (`~/.claude/agents/`) with cross-project memory.
It reviews the committed code adversarially, looking for:
- Key material leakage
- Timing side-channels
- Malformed input handling
- Signature malleability
- Any OWASP-relevant concerns

Findings are commented on the PR. Critical/High findings block merge.

---

## Shutdown Sequence

1. Developer(s) shut down first (work is complete, findings are on GitHub issues)
2. Analyst shuts down second
3. PM shuts down last (after PR is created)
4. White-hat (if spawned) shuts down after audit is posted

No agent should need to message a peer during shutdown. All observations are
captured on GitHub issues or PR comments — durable, visible, order-independent.

---

## Error Handling

If any phase fails:
1. **Do not proceed** to the next phase
2. Report the failure clearly with context
3. Preserve all work (no discarding, no force-resetting)
4. Ask user how to proceed: retry, skip, or abort

If a developer encounters a blocker mid-implementation:
- Comment the blocker on the relevant GitHub issue
- Mark the task as blocked
- Report to team lead
- Do not attempt to work around fundamental blockers silently

---

## Design Decisions

These choices are based on observed behaviour across multiple HLR runs:

| Decision | Rationale |
|----------|-----------|
| Analyst proposes breakdown | The analyst understands the technical work; the PM understands issue management — each does what they're best at |
| PM creates sub-issues | Sub-issues are a project management artefact; the PM owns them |
| Parallel developers | Independent sub-tasks can be implemented concurrently by multiple developers |
| Analyst always on | Zero token cost when idle; available for developer consultation, and observing implementations builds analyst memory for future HLRs |
| More agents, not fewer | AI agents don't suffer the same nodes/edges overhead as human teams; the upper bound is likely much higher than intuition suggests |
| GitHub issue comments over DMs | Durable, visible, survives shutdown, avoids combinatorial shutdown ordering |
| No manual nudging | Trust task dependencies; bypassing them causes premature task starts |
| White-hat is global | Security knowledge is cross-cutting; benefits from cross-project memory |
| Developer writes to /tmp/ | Avoids permission prompts for multi-line scripts with # comments |
| PM does commits, not developer | Separation of concerns; PM verifies before committing |

---

## Notes

- **Idempotent**: Safe to re-run — skips closed sub-issues automatically
- **Resumable**: If interrupted, re-run to continue from next open sub-issue
- **No force push**: Never rewrites history or force pushes
- **British English**: All commits, comments, and documentation use British spelling
- **Self-contained**: This command orchestrates the full lifecycle — no external
  skill dependencies

# Plan Management Playbook

How to manage plans throughout their lifecycle—from rough ideas to implementation-ready projects.

---

## Where Does This Plan Go?

| If the plan is... | Put it in... |
|-------------------|--------------|
| Ad-hoc / scratch / in-progress | `~/.claude/plans/` |
| Linked to a GitHub Issue | `<project>/.claude/plans/` |
| A formalised procedure | `~/.claude/playbooks/` |

**Default**: Plans start in `~/.claude/plans/`. When linked to a specific issue, move to the project and rename with date prefix.

---

## Plan States

Plans progress through distinct states. Each transition requires explicit action.

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   DRAFTING  │────▶│ FIRST DRAFT │────▶│  REVIEWED   │────▶│ PROJECT     │────▶│   READY     │
│   (WIP)     │     │             │     │             │     │ SETUP       │     │             │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
      │                   │                   │                   │                   │
      ▼                   ▼                   ▼                   ▼                   ▼
   Iterate            Reviews            Incorporate          Housekeeping       Explicit
   Refine             Requested          Findings             Complete           Instruction
```

### State Definitions

| State | Description | Exit Criteria |
|-------|-------------|---------------|
| **Drafting** | Iterative refinement; multiple WIP snapshots | User says "first draft complete" or similar |
| **First Draft** | Plan structure complete, ready for review | Specialist review(s) requested |
| **Reviewed** | Review findings incorporated | User confirms final draft |
| **Project Setup** | Housekeeping in progress | All setup tasks complete |
| **Ready** | Implementation may begin | User gives explicit instruction to start |

---

## State: Drafting (WIP)

During drafting, save progress frequently:

1. **Save WIP snapshots** — When pausing work, save current state to plan file
2. **Iterate freely** — Refinement may take multiple sessions
3. **No premature structure** — Content first, polish later

**Transition to First Draft:**
- User explicitly indicates the draft is complete
- Example phrases: "first draft done", "ready for review", "let's get this reviewed"

---

## State: First Draft → Reviewed

Request specialist reviews based on plan content:

| Plan Involves | Request Review From |
|---------------|---------------------|
| Security implications | Security Specialist |
| Infrastructure/deployment | DevOps Specialist |
| Database changes | Database Specialist |
| API changes | API Specialist |
| Implementation phases | Implementation Specialist |
| Multiple domains | Architecture review (multi-specialist) |

**Process:**
1. Request review(s) — May be sequential or parallel
2. Receive findings — Document in plan or separate review file
3. Incorporate findings — Update plan as needed
4. Iterate if necessary — May need additional review rounds

**Transition to Reviewed:**
- All requested reviews complete
- Findings incorporated
- User confirms "final draft" or similar

---

## State: Project Setup (Housekeeping)

Before implementation begins, complete project housekeeping:

### 1. Create Tracking Issue
- Unless an issue already exists
- This becomes the main project tracking issue
- Label with `Phase: Project Tracking`

### 2. Break Down with `/project:plan:tasks`
Skip this step only if the plan is obviously a single atomic task.

```
/project:plan:tasks <tracking-issue-number>
```

This creates:
- **Top-level tasks** — Correlate to Implementation Plan phases
- **Sub-tasks** — Granular work items within each phase
- **Issue hierarchy** — Tasks become sub-issues of tracking issue

### 3. Update Documentation
- Add issue references to plan
- Add issue references to any review documents
- Cross-link related documentation

### 4. Create Documentation Branch
```
Branch: docs/<tracking-issue>_<plan-name>
```

Commit all documentation:
- Plan file(s)
- Review documents
- Updated cross-references

### 5. Create Documentation PR
- PR merges docs to master
- **Does NOT close the tracking issue**
- Provides clean master with linked documentation

### 6. Merge and Sync
After PR merges:
- Sync local master with upstream
- Documentation now in master
- Ready to create implementation branches

**Transition to Ready:**
- All housekeeping steps complete
- Documentation merged to master
- User confirms setup is complete

---

## State: Ready

The plan is ready for implementation, but work does not begin automatically.

**Critical Rule:** Only begin implementation when the user explicitly says to start.

Explicit start phrases:
- "go ahead"
- "start implementing"
- "begin phase 1"
- "let's start"

**Not** explicit:
- "looks good" (approval, not instruction)
- "ready" (acknowledgement, not instruction)
- Exiting plan mode (confirmation, not instruction)

---

## Lifecycle Actions

### Completing a Plan

When implementation is complete, move plan to `completed/` subfolder:

```
~/.claude/plans/foo.md           → ~/.claude/plans/completed/foo.md
<project>/.claude/plans/bar.md   → <project>/.claude/plans/completed/bar.md
```

### Promoting to Playbook

When a completed plan proves stable and reusable:

1. Create `~/.claude/playbooks/<name>.md`
   - Distil to actionable steps
   - Remove research/rationale context
   - Keep it concise

2. Delete or archive the original plan

---

## Naming Conventions

| Location | Format | Example |
|----------|--------|---------|
| `~/.claude/plans/` | Auto-generated | `flickering-wishing-key.md` |
| `~/.claude/playbooks/` | Descriptive kebab-case | `development-workflow.md` |
| `<project>/.claude/plans/` | Date-prefixed | `20260108-initial-architecture.md` |

---

## Housekeeping

Periodically review `~/.claude/plans/completed/`:

- **Delete** — no longer relevant
- **Promote** — stable procedures → `~/.claude/playbooks/`

---

## Quick Reference

| User Says | Current State | Action |
|-----------|---------------|--------|
| "save this" / "let's pause" | Drafting | Save WIP snapshot |
| "first draft done" / "ready for review" | Drafting | Transition to First Draft |
| "get security review" | First Draft | Request specialist review |
| "incorporate findings" | First Draft | Update plan, may iterate |
| "final draft" | First Draft | Transition to Reviewed |
| "set up the project" | Reviewed | Begin Project Setup |
| "go ahead" / "start" | Ready | Begin implementation |

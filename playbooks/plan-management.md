# Plan Management Playbook

How to manage plans throughout their lifecycle.

---

## Where Does This Plan Go?

| If the plan is... | Put it in... |
|-------------------|--------------|
| Ad-hoc / scratch / in-progress | `~/.claude/plans/` |
| Linked to a GitHub Issue | `<project>/.claude/plans/` |
| A formalised procedure | `~/.claude/playbooks/` |

**Default**: Plans start in `~/.claude/plans/`. When a plan becomes linked to a specific issue, move it to the project (current working project unless specified otherwise) and rename with date prefix.

---

## Lifecycle Actions

### Finishing a Plan

When a plan is marked as completed, move it to a `completed/` subfolder within its current directory:

```
~/.claude/plans/foo.md           → ~/.claude/plans/completed/foo.md
<project>/.claude/plans/bar.md   → <project>/.claude/plans/completed/bar.md
```

### Promoting to Playbook

When a completed plan proves stable and reusable:

```
1. Create ~/.claude/playbooks/<name>.md
   - Distil to actionable steps
   - Remove research/rationale context
   - Keep it concise

2. Delete or keep the original plan as reference
```

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
- **Promote** — stable procedures (→ `~/.claude/playbooks/`)


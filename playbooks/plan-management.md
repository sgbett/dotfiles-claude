# Plan Management Playbook

How to manage plans throughout their lifecycle.

---

## Where Does This Plan Go?

| If the plan is... | Put it in... |
|-------------------|--------------|
| Active work, scratch, in-progress | `~/.claude/plans/` |
| Worth keeping as reference | `~/.claude/plans-reference/` |
| A formalised procedure | `~/.claude/playbooks/` |
| Specific to a project | `<project>/.claude/plans/` |

---

## Lifecycle Actions

### Finishing a Working Plan

When done with a plan in `~/.claude/plans/`:

```
1. Is it worth keeping?
   ├── No  → Delete it
   └── Yes → Is it project-specific?
             ├── Yes → Move to <project>/.claude/plans/yyyymmdd-name.md
             └── No  → Move to ~/.claude/plans-reference/name.md
```

### Promoting to Playbook

When a reference plan proves stable:

```
1. Create ~/.claude/playbooks/<name>.md
   - Distil to actionable steps
   - Remove research/rationale context
   - Keep it concise

2. Update source plan header:
   **Playbook**: See [`~/.claude/playbooks/<name>.md`](../playbooks/<name>.md)

3. Commit both files together
```

---

## Naming Conventions

| Location | Format | Example |
|----------|--------|---------|
| `plans/` | Auto-generated | `flickering-wishing-key.md` |
| `plans-reference/` | Descriptive kebab-case | `framework-integration-minimal.md` |
| `playbooks/` | Descriptive kebab-case | `development-workflow.md` |
| `<project>/.claude/plans/` | Date-prefixed | `20260108-initial-architecture.md` |

---

## Housekeeping

Periodically review `~/.claude/plans/`:

- **Delete** — no longer relevant
- **Rename & move** — worth keeping (→ `plans-reference/`)
- **Move to project** — project-specific (→ `<project>/.claude/plans/`)

---

## Background

See `~/.claude/plans-reference/plan-organization-guidelines.md` for full rationale.

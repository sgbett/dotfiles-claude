# Plan Organisation Guidelines

## Directory Convention

| Directory | Purpose | Version Control | Naming |
|-----------|---------|-----------------|--------|
| `~/.claude/plans/` | Working memory | ❌ gitignored | Auto-generated |
| `~/.claude/plans-reference/` | Reference documentation | ✅ Tracked | Descriptive kebab-case |
| `~/.claude/playbooks/` | Formalised procedures | ✅ Tracked | Descriptive kebab-case |
| `<project>/.claude/plans/` | Project-specific plans | ✅ With project | Date-prefixed |

---

## Working Memory (`~/.claude/plans/`)

**Purpose**: Active session context, ephemeral working documents.

- Auto-generated whimsical names (e.g., `flickering-wishing-key.md`)
- Not version controlled (in `.gitignore`)
- Persist until manually deleted
- Use for in-progress work, scratch space, session continuity

**Housekeeping**: Periodically review and either:
- Delete if no longer relevant
- Move to `plans-reference/` if worth keeping as reference
- Move to project `.claude/plans/` if project-specific

---

## Reference Plans (`~/.claude/plans-reference/`)

**Purpose**: Completed plans worth keeping as reference — research, analysis, how we arrived at decisions.

- Descriptive kebab-case names (e.g., `framework-integration-analysis.md`)
- Version controlled with `~/.claude` repo
- Cross-project reference material
- **Not prescriptive** — context and rationale, not strict procedures

**Examples**:
- `framework-integration-analysis.md` — Research and analysis journey
- `framework-integration-minimal.md` — Integration approach we arrived at
- `ruby-fetch-improvement-plan.md` — MCP server documentation

---

## Playbooks (`~/.claude/playbooks/`)

**Purpose**: Formalised, prescriptive procedures — "here's how we do X".

- Descriptive kebab-case names (e.g., `greenfield-project-setup.md`)
- Version controlled with `~/.claude` repo
- **Prescriptive** — established procedures to follow
- Distilled from reference plans once proven

**When to create a playbook**:
- A reference plan has been validated through practical use
- The approach is stable and worth standardising
- You want a concise, actionable guide without the research context

**Relationship to plans-reference**:
```
plans-reference/framework-integration-minimal.md  (the journey, rationale)
         │
         ▼ (formalise when proven)
playbooks/development-workflow.md                 (the procedure)
```

**Cross-referencing**: When a playbook is created from a plan, add a link in the source plan's header:
```markdown
**Playbook**: See [`~/.claude/playbooks/<name>.md`](../playbooks/<name>.md)
```

This maintains traceability from rationale → procedure.

---

## Project-Specific Plans (`<project>/.claude/plans/`)

**Purpose**: Plans tied to a specific project's lifecycle.

**Naming**: Date-prefixed for chronological ordering:
```
<project>/.claude/plans/
├── 20260108-initial-architecture.md
├── 20260115-payment-integration.md
└── 20260122-performance-optimisation.md
```

**Format**: `yyyymmdd-descriptive-name.md`

This provides:
- Chronological ordering in file listings
- Clear creation date without checking git history
- Consistency with `.architecture/decisions/adrs/` naming

**Version control**: Committed with the project repository.

---

## Lifecycle Flow

```
[Auto-generated plan in ~/.claude/plans/]
         │
         ▼
    Work on it
         │
         ├──► Delete (no longer needed)
         │
         ├──► Move to plans-reference/ (worth keeping as reference)
         │         │
         │         ▼ (optional: formalise when proven)
         │    playbooks/ (prescriptive procedure)
         │
         └──► Move to <project>/.claude/plans/ (project-specific)
```

---

## CLAUDE.md Integration

Projects can reference plans or playbooks in their CLAUDE.md:

```markdown
## Workflow

This project uses **Tier 1** workflow (spec-kit heavy for greenfield).

Playbook: `~/.claude/playbooks/greenfield-project-setup.md`
Background: `~/.claude/plans-reference/framework-integration-minimal.md`

Project-specific deviations:
- [Any project-specific adjustments]
```

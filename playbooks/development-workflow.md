# Development Workflow Playbook

Choose the appropriate tier based on scope, then follow the steps.

---

## Tier Selection

| Scope | Tier | Ceremony |
|-------|------|----------|
| New project, major feature, architectural change | **Tier 1** | Full |
| Significant feature, multi-file change | **Tier 2** | Moderate |
| Bug fix, small change, single-file tweak | **Tier 3** | Minimal |

**When in doubt**: Start with Tier 2. Escalate to Tier 1 if complexity emerges.

---

## Tier 1: Greenfield / Major Feature

Use for new projects, major features, or significant architectural changes.

```
1. /speckit.constitution      # Project principles (once per project)
2. /speckit.specify <desc>    # Define requirements and edge cases
3. /speckit.clarify           # Refine spec if needed
4. architecture-review        # Multi-specialist validation
5. create-adr                 # Document significant decisions
6. /project:plan:tasks <#>    # Break down into GitHub Issues
7. [Implement]                # Claude Code native
8. /review                    # Validate before merge
```

**Optional**: `/speckit.analyze` after step 6 to check consistency.

---

## Tier 2: Significant Feature

Use for features that touch multiple files or have architectural implications.

```
1. Create GitHub Issue        # Manual or /project:plan:tasks
2. specialist-review          # If architectural concerns (optional)
3. create-adr                 # If significant decision (optional)
4. [Implement]                # Claude Code native
5. /review                    # Validate before merge
```

**Tip**: If step 2 reveals complexity, consider escalating to Tier 1.

---

## Tier 3: Bug Fix

Use for bug fixes, small changes, and low-risk modifications.

```
1. GitHub Issue               # Create or reference existing
2. [Implement]                # Claude Code native
3. PR closes Issue            # Link in commit/PR
```

---

## Quick Reference

| Command | Purpose |
|---------|---------|
| `/speckit.constitution` | Establish project principles |
| `/speckit.specify <desc>` | Create feature specification |
| `/speckit.clarify` | Refine spec with targeted questions |
| `/speckit.analyze` | Cross-artifact consistency check |
| `/project:plan:tasks <#>` | Break Issue into sub-issues |
| `specialist-review` | Domain-focused review |
| `architecture-review` | Multi-specialist review |
| `create-adr` | Document architectural decision |
| `pragmatic-guard` | Enable YAGNI enforcement |
| `/review` | Code review (native) |
| `/security-review` | Security-focused review (native) |

---

## Background

See `~/.claude/plans-reference/framework-integration-minimal.md` for rationale.

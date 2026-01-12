# Specialist Review Timing Guide

Quick reference for when and how to use specialist reviews during development.

## Two Types of Review

| Review Type | Target | When | Catches |
|-------------|--------|------|---------|
| **Plan Review** | Plan document | Before implementation | Gaps in approach, missing steps, wrong assumptions |
| **PR Review** | Actual code diff | Before merge | Implementation gaps, forgotten files, scope issues |

**Key insight**: Plan reviews check *what you intend to do*. PR reviews check *what you actually did*.

## Review Timing

```
┌─────────────────────────────────────────────────────────────┐
│  PLAN CREATED                                               │
│       ↓                                                     │
│  ★ Plan Review (catches strategic issues)                   │
│       ↓                                                     │
│  PHASE 1 COMPLETE                                           │
│       ↓                                                     │
│  ★ Re-review (optional gate check)                          │
│       ↓                                                     │
│  PHASE 2 COMPLETE                                           │
│       ↓                                                     │
│  PR CREATED                                                 │
│       ↓                                                     │
│  ★ PR Review (catches implementation gaps)                  │
│       ↓                                                     │
│  MERGE                                                      │
│       ↓                                                     │
│  PRODUCTION DEPLOY                                          │
│       ↓                                                     │
│  ★ Post-deploy verification (optional)                      │
└─────────────────────────────────────────────────────────────┘
```

## When to Request Each

### Plan Review
Request when:
- Starting a multi-phase project
- Making infrastructure changes
- Before significant implementation work

Ask: `/specialist-review [Specialist] review the plan for [feature]`

### Re-review (Gate Check)
Request when:
- Completing a phase with explicit gate criteria
- Original review recommended a re-review point
- Significant discoveries during implementation

Ask: `/specialist-review [Specialist] re-review [plan] after Phase N`

### PR Review
Request when:
- PR is ready for merge
- Implementation is complete
- Want to catch "what we forgot to change"

Ask: `/specialist-review [Specialist] review PR #NNN`

## Document Strategy

### Option A: Single Document (simpler)
- All reviews update the same document
- Adds sections: "Phase 1 Status", "PR Review", etc.
- Good for: Smaller projects, linear progression

### Option B: Separate Documents (clearer audit trail)
- Plan review: `specialist-topic.md`
- PR review: `specialist-pr123-topic.md`
- Good for: Larger projects, distinct review scopes

## What Each Specialist Catches

| Specialist | Plan Review Focus | PR Review Focus |
|------------|-------------------|-----------------|
| **Implementation Strategist** | Sequencing, blast radius, reversibility | Bundled concerns, timing issues |
| **DevOps** | Infrastructure approach, environment strategy | Environment parity, missing configs |
| **Security** | Auth approach, data handling | Actual vulnerabilities, secrets |
| **Performance** | Scaling strategy, caching approach | N+1 queries, missing indexes |

## Lessons from PostgreSQL Upgrade

1. **Plan review caught**: Missing go/no-go gates, unclear staging approach, no team coordination
2. **Plan review missed**: CI configuration (wasn't in plan scope)
3. **PR review caught**: CI not updated, `\restrict` lines in structure.sql

**Takeaway**: Plan reviews check the plan. If something isn't in the plan, it won't be caught. PR reviews check the actual implementation against what *should* have changed.

## Version Upgrade Parity Checklist

For any version upgrade, ensure all environments are checked:

- [ ] Local Docker configuration
- [ ] CI/CD pipeline (GitHub Actions, etc.)
- [ ] Staging infrastructure
- [ ] Production infrastructure
- [ ] Documentation (DEVELOPMENT.md, etc.)

## Quick Commands

```bash
# Plan review
/specialist-review DevOps review the upgrade plan

# Gate check / re-review
/specialist-review Implementation Strategist re-review plan after Phase 1

# PR review
/specialist-review DevOps review PR #1114

# Multiple specialists on same target
/specialist-review Security Specialist review PR #1114
/specialist-review Performance Specialist review PR #1114
```

## When to Skip Reviews

- Trivial changes (typos, small docs updates)
- Single-file bug fixes with obvious scope
- Changes with no infrastructure/security/performance implications

## Embedding Review Checkpoints in Plans

For multi-phase projects, embed review checkpoints directly in the plan document. This keeps the plan as the single source of truth for both implementation steps and governance gates.

### Pattern

After each phase section in your plan, add a checkpoint block:

```markdown
### Phase N Review Checkpoint

**Review Type** (required|recommended|optional):
- **When**: [Trigger condition]
- **Specialists**: [Who should review]
- **Focus**: [What they should look for]
- **Gate**: [What must pass before proceeding]
```

### Example: Strong Parameters Migration

```markdown
### Phase 0 Review Checkpoints

**Progress Review** (optional, mid-phase):
- **When**: After high-priority controllers have attribute verification
- **Review**: `.architecture/reviews/impl-strategist-phase0-progress.md`
- **Purpose**: Validate approach is working; identify blockers early

**Completion Review** (required):
- **When**: Before declaring Phase 0 complete
- **Review**: Request Implementation Strategist re-review
- **Gate**: Must confirm all success criteria met before Phase 1
```

### Tracking Review Status

Add a summary table at the end of the plan:

```markdown
## Specialist Reviews

### Initial Plan Reviews

| Specialist | Review | Status |
|------------|--------|--------|
| Implementation Strategist | `.architecture/reviews/impl-strategist-plan.md` | ✅ Complete |
| Security Specialist | `.architecture/reviews/security-plan.md` | ✅ Complete |

### Checkpoint Reviews

| Phase | Review | Status |
|-------|--------|--------|
| Pre-Flight | `.architecture/reviews/impl-strategist-preflight.md` | ✅ Complete |
| Phase 0 Progress | `.architecture/reviews/impl-strategist-phase0-progress.md` | ✅ Complete |
| Phase 0 Completion | (request when ready) | ⏳ Pending |
| Phase 1 Mid-Phase | (Security, Ruby Expert) | ⏳ Pending |
```

### Benefits

1. **Single source of truth**: No need to remember when reviews happen
2. **Clear gates**: Each phase has explicit entry/exit criteria
3. **Progress tracking**: Status table shows what's done and what's pending
4. **Audit trail**: Completed reviews link to actual review documents
5. **Specialist assignment**: Each checkpoint specifies who should review

### When to Use This Pattern

- Multi-phase migrations (Rails upgrades, gem replacements)
- Security-sensitive changes (auth, permissions, data handling)
- Infrastructure changes with rollback concerns
- Any project where "did we review this?" might be asked later

### Review Document Naming

Keep checkpoint reviews clearly linked to the plan:

```
.architecture/reviews/
├── [specialist]-[topic]-plan.md           # Initial plan review
├── [specialist]-[topic]-preflight.md      # Pre-flight checkpoint
├── [specialist]-[topic]-phase0-progress.md # Mid-phase progress
├── [specialist]-[topic]-phase1-security.md # Phase-specific review
└── [specialist]-[topic]-final.md          # Completion review
```

### Updating the Plan After Reviews

When a review is completed:
1. Update the checkpoint status from ⏳ to ✅
2. Add the review document path
3. If the review identified blockers, note them in the relevant phase section

## Summary

1. **Review the plan** before starting significant work
2. **Embed checkpoints** in multi-phase plans for clear governance
3. **Re-review at gates** if the original review recommended it
4. **Track status** in the plan's review summary table
5. **Review the PR** before merge to catch implementation gaps
6. **Use checklists** for version upgrades to ensure parity
7. **Separate documents** for plan vs PR reviews (clearer audit trail)

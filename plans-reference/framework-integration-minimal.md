# Framework Integration: Minimal Plan

**Analysis/Journey**: See [`framework-integration-analysis.md`](framework-integration-analysis.md) for comprehensive research, specialist reviews, and how we arrived at this minimal approach.

**Playbook**: See [`~/.claude/playbooks/development-workflow.md`](../playbooks/development-workflow.md) for the distilled, actionable workflow.

---

Based on comparison of Claude Code native capabilities vs the three frameworks.

---

## Claude Code Already Does

| Capability | Native Support | How |
|------------|----------------|-----|
| **PR creation** | ✅ Yes | GitHub Actions + `@claude` mentions |
| **Code review** | ✅ Yes | `/review`, `/security-review` |
| **Session management** | ✅ Yes | `/resume`, `/rename`, `/rewind` |
| **Task tracking (session)** | ✅ Yes | `/todos`, TodoWrite |
| **Project config** | ✅ Yes | CLAUDE.md, `.claude/rules/` |
| **Plans/working memory** | ✅ Yes | `~/.claude/plans/` |

---

## Claude Code Does NOT Have

| Capability | Gap | Framework That Fills It |
|------------|-----|-------------------------|
| **GitHub Issue creation** | No native way to create Issues | claude-workflow |
| **Architecture Decision Records** | No ADR support | ai-software-architect |
| **Multi-specialist reviews** | `/review` is generic, not domain-specific | ai-software-architect |
| **YAGNI/complexity enforcement** | No native mechanism | ai-software-architect |
| **Specification-first workflow** | No formal spec system | spec-kit |
| **Constitutional principles** | No project governance | spec-kit |

---

## Redundancy Analysis by Framework

### claude-workflow

| Feature | Redundant? | Recommendation |
|---------|------------|----------------|
| `/project:plan:prd` | Partial | Skip — use spec-kit or Issue description |
| `/project:plan:feature` | Partial | Skip — redundant with spec-kit |
| `/project:plan:tasks` → Issues | **No** | **Keep** — converts tasks to GitHub Issues |
| `/project:do:task` | Partial | Evaluate — adds PR linking, but GitHub Actions does PRs |
| `/project:current` | Low value | Skip — session context + `/todos` covers this |

**Verdict**: Only `/project:plan:tasks` (Issue creation) is genuinely additive.

---

### ai-software-architect

| Feature | Redundant? | Recommendation |
|---------|------------|----------------|
| `create-adr` | **No** | **Keep** — no native ADR support |
| `architecture-review` | **No** | **Keep** — multi-specialist is beyond `/review` |
| `specialist-review` | **No** | **Keep** — domain-focused reviews |
| `pragmatic-guard` | **No** | **Keep** — no native YAGNI enforcement |
| `architecture-status` | **No** | **Keep** — ADR health check |
| `setup-architect` | **No** | **Keep** — framework setup |
| `list-members` | Low value | Optional — nice-to-have |

**Verdict**: Keep entire framework — fills genuine gaps.

---

### spec-kit

| Feature | Redundant? | Recommendation |
|---------|------------|----------------|
| `/speckit.constitution` | **No** | **Keep** — no native governance |
| `/speckit.specify` | Partial | **Evaluate** — could use Issue descriptions instead |
| `/speckit.plan` | Partial | Partial overlap with `~/.claude/plans/` |
| `/speckit.tasks` | Partial | Partial overlap with TodoWrite (but persistent) |
| `/speckit.clarify` | **No** | **Keep** — iterative refinement |
| `/speckit.implement` | High redundancy | Skip — Claude Code does this natively |
| `/speckit.analyze` | **No** | **Keep** — consistency validation |

**Verdict**: Core value is constitutional governance and formal specifications. Implementation features are redundant.

---

## Minimal Integration Recommendation

### Definitely Keep (Genuine Gaps)

1. **ai-software-architect** — Full framework
   - ADRs fill a real gap
   - Multi-specialist reviews go beyond `/review`
   - Pragmatic Guard is unique
   - You already have this installed

2. **claude-workflow** — Issue creation only
   - `/project:plan:tasks` for GitHub Issue creation
   - Skip other commands (redundant with spec-kit or native)

3. **spec-kit** — Governance layer only
   - `/speckit.constitution` — Project principles
   - `/speckit.specify` — If you want formal specs beyond Issue descriptions
   - Skip `/speckit.implement` — Claude Code does this

### Skip or Defer

| Feature | Reason |
|---------|--------|
| `/project:plan:prd` | Redundant with spec-kit |
| `/project:plan:feature` | Redundant with spec-kit |
| `/project:do:task` | GitHub Actions handles PRs |
| `/speckit.implement` | Claude Code is the implementation tool |
| Complex session protocols | Native session management is sufficient |

---

## Revised Workflow (Minimal)

```
For Tier 1 (New Project/Major Feature):
1. /speckit.constitution — Establish principles (once per project)
2. /speckit.specify — Define requirements
3. architecture-review or specialist-review — Validate design
4. create-adr — Document decisions
5. /project:plan:tasks — Create GitHub Issues
6. Implement with Claude Code (native)
7. /review or /security-review — Validate (native)

For Tier 2 (Significant Feature):
1. Create GitHub Issue manually or via /project:plan:tasks
2. specialist-review if architectural (optional)
3. create-adr if significant decision (optional)
4. Implement with Claude Code (native)
5. /review (native)

For Tier 3 (Bug Fix):
1. Create/use GitHub Issue
2. Implement with Claude Code (native)
3. PR closes Issue
```

---

## What This Eliminates

| From Original Plan | Status |
|--------------------|--------|
| Session-to-plan handoff protocol | **Removed** — native sessions sufficient |
| Complex CLAUDE.md template | **Simplified** — native config works |
| Multiple command namespaces concern | **Reduced** — fewer commands |
| Phased 4-week pilot | **Simplified** — less to pilot |

---

## Final Decisions

Based on your input:

| Question | Answer |
|----------|--------|
| Formal specifications? | **Yes, for greenfield** |
| Automated Issue creation? | **Yes** |
| ai-software-architect features? | **Full framework** |

---

## Final Integration Plan

### What to Install/Keep

| Framework | Features to Use | Features to Skip |
|-----------|-----------------|------------------|
| **ai-software-architect** | Everything (already installed) | — |
| **claude-workflow** | `/project:plan:tasks` only | `/project:plan:prd`, `/project:plan:feature`, `/project:do:task` |
| **spec-kit** | `/speckit.constitution`, `/speckit.specify` (greenfield only) | `/speckit.implement`, `/speckit.plan` |

### Installation Steps

1. **ai-software-architect** — Already installed ✅
   - Skills in `~/.claude/skills/`
   - `.architecture/` directory ready

2. **claude-workflow** — Partial install
   - Copy only `/project:plan:tasks` command from `.claude/commands/`
   - Skip other commands to avoid redundancy

3. **spec-kit** — Selective install (greenfield only)
   - `/speckit.constitution` for new projects
   - `/speckit.specify` for major features
   - Skip implementation commands

### Simplified Workflows

**Greenfield (Tier 1)**:
```
1. /speckit.constitution — Project principles
2. /speckit.specify — Requirements + edge cases
3. architecture-review — Multi-specialist validation
4. create-adr — Document decisions
5. /project:plan:tasks — Create GitHub Issues
6. [Claude Code native implementation]
7. /review or /security-review — Validate
```

**Significant Feature (Tier 2)**:
```
1. specialist-review — If architectural concerns
2. create-adr — If significant decision
3. /project:plan:tasks — Create Issues (or manual)
4. [Claude Code native implementation]
5. /review — Validate
```

**Bug Fix (Tier 3)**:
```
1. Create/use GitHub Issue
2. [Claude Code native implementation]
3. PR closes Issue
```

---

## What's NOT Needed (Claude Code Handles It)

| Concern from Original Plan | Resolution |
|---------------------------|------------|
| Session-to-plan handoff | Native `/resume`, `/rename` sufficient |
| Complex CLAUDE.md template | Native config works |
| PR creation/linking | GitHub Actions handles this |
| Implementation orchestration | Claude Code is the implementation tool |

---

## Installation Status

All frameworks installed (2026-01-08):

| Framework | Status | Location |
|-----------|--------|----------|
| **ai-software-architect** | ✅ Installed | `~/.claude/skills/` |
| **claude-workflow** | ✅ Installed | `~/.claude/commands/project/plan/tasks.md` |
| **spec-kit** | ✅ Installed | `~/.claude/commands/speckit/` |

### Installed Commands

```
~/.claude/commands/
├── project/plan/tasks.md      # /project:plan:tasks
└── speckit/
    ├── analyze.md             # /speckit.analyze
    ├── clarify.md             # /speckit.clarify
    ├── constitution.md        # /speckit.constitution
    └── specify.md             # /speckit.specify

~/.claude/speckit/
├── memory/constitution.md     # Constitution template
└── templates/spec-template.md # Spec template
```

## Next Steps

1. **Test with next greenfield project** or significant feature
2. Refine workflows based on practical usage

No need for:
- 4-phase pilot (simplified scope)
- Session handoff protocols (native is fine)
- Expanded CLAUDE.md (current setup works)

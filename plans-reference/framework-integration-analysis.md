# Analysis: Integrating claude-workflow, ai-software-architect, and spec-kit

## Project Summaries

### 1. sbusso/claude-workflow
**Purpose**: GitHub Issues-based project management using Claude Code slash commands.

**Key Commands**:
- `/project:plan:prd` — Create Product Requirements Documents
- `/project:plan:feature` — Generate feature specifications
- `/project:plan:tasks` — Break work into hierarchical tasks
- `/project:do:task` — Execute tasks with AI guidance
- `/project:current` — Show project context

**Strengths**:
- Native GitHub integration (Issues, labels, PR linking)
- Zero external dependencies
- Automatic project type detection
- Context-aware templates by language/framework

**Artifacts**: GitHub Issues with structured descriptions

---

### 2. codenamev/ai-software-architect
**Purpose**: Multi-perspective architectural governance and decision documentation.

**Key Commands** (skills):
- `setup-architect` — Initialise framework
- `create-adr` — Create Architectural Decision Records
- `architecture-review` — Full multi-perspective review (9 specialists)
- `specialist-review` — Single specialist review
- `pragmatic-guard` — YAGNI enforcement mode
- `architecture-status` — Documentation health check

**Strengths**:
- Structured ADR management with versioning
- Multi-perspective analysis (Security, Performance, Maintainability, etc.)
- Pragmatic Guard mode prevents over-engineering
- AI-agnostic (Claude, Cursor, Copilot)

**Artifacts**: ADRs, review documents, implementation roadmaps in `.architecture/`

---

### 3. github/spec-kit
**Purpose**: Spec-Driven Development — specifications as executable, generative artifacts.

**Key Commands**:
- `/speckit.constitution` — Establish governing principles
- `/speckit.specify` — Define functional specifications
- `/speckit.plan` — Create implementation plans
- `/speckit.tasks` — Generate task breakdowns
- `/speckit.implement` — Execute implementation
- `/speckit.clarify` — Refine underspecified areas
- `/speckit.analyze` — Validate consistency

**Strengths**:
- Specification-first philosophy (specs generate code, not vice versa)
- Constitutional principles (test-first, library-first, simplicity)
- Multi-agent support (16 AI agents)
- Regeneration cycle for evolving requirements

**Artifacts**: PRDs, implementation plans, task lists in markdown

---

## Overlap Analysis

| Capability | claude-workflow | ai-software-architect | spec-kit |
|------------|-----------------|----------------------|----------|
| PRD/Requirements | `/project:plan:prd` | — | `/speckit.specify` |
| Feature specs | `/project:plan:feature` | — | `/speckit.specify` |
| Task breakdown | `/project:plan:tasks` | — | `/speckit.tasks` |
| Implementation | `/project:do:task` | — | `/speckit.implement` |
| Architecture decisions | — | `create-adr` | — |
| Architecture review | — | `architecture-review` | — |
| YAGNI enforcement | — | `pragmatic-guard` | Constitutional articles |
| Project tracking | GitHub Issues | `.architecture/` docs | Markdown artifacts |

### Direct Overlaps (Potential Conflicts)
1. **PRD Creation**: `claude-workflow` and `spec-kit` both create PRDs
2. **Task Breakdown**: Both have task generation commands
3. **YAGNI/Simplicity**: `ai-software-architect` has Pragmatic Guard; `spec-kit` has constitutional articles

### Complementary Areas (No Overlap)
1. **Architecture Reviews**: Only `ai-software-architect` provides multi-perspective specialist reviews
2. **ADRs**: Only `ai-software-architect` manages architectural decision records
3. **GitHub Issues**: Only `claude-workflow` creates native GitHub Issues
4. **Constitutional Governance**: Only `spec-kit` has formal constitutional principles
5. **Specification Regeneration**: Only `spec-kit` supports regenerating implementations from specs

---

## Integration Strategy

### Recommended Workflow Layers

```
┌─────────────────────────────────────────────────────────────┐
│  LAYER 1: GOVERNANCE (spec-kit)                             │
│  /speckit.constitution — Establish project principles       │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  LAYER 2: SPECIFICATION (spec-kit)                          │
│  /speckit.specify — Define requirements with edge cases     │
│  /speckit.clarify — Refine ambiguous areas                  │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  LAYER 3: ARCHITECTURE (ai-software-architect)              │
│  create-adr — Document significant decisions                │
│  architecture-review — Multi-perspective validation         │
│  pragmatic-guard — Challenge unnecessary complexity         │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  LAYER 4: PLANNING (spec-kit)                               │
│  /speckit.plan — Technical implementation plan              │
│  /speckit.tasks — Detailed task breakdown                   │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  LAYER 5: TRACKING (claude-workflow)                        │
│  /project:plan:tasks — Create GitHub Issues from tasks      │
│  /project:do:task — Execute with PR linking                 │
└─────────────────────────────────────────────────────────────┘
```

### Role Assignment

| Phase | Primary Tool | Rationale |
|-------|--------------|-----------|
| **Principles** | spec-kit | Constitutional framework establishes immutable rules |
| **Requirements** | spec-kit | Spec-first approach with edge case identification |
| **Architecture** | ai-software-architect | Multi-perspective review catches blind spots |
| **Technical Planning** | spec-kit | Plans tied to specifications for regeneration |
| **Issue Tracking** | claude-workflow | Native GitHub integration for visibility |
| **Implementation** | spec-kit or claude-workflow | Both viable; spec-kit for spec-regeneration, claude-workflow for GitHub PR flow |

### Conflict Resolution

**PRD/Requirements**: Use **spec-kit** for specifications (more rigorous edge-case handling), skip `claude-workflow`'s PRD command.

**Task Breakdown**: Use **spec-kit** for generating task lists, then **claude-workflow** to convert tasks into GitHub Issues for tracking.

**YAGNI Enforcement**: Use **ai-software-architect's** Pragmatic Guard (configurable intensity, exemptions for security/compliance) rather than spec-kit's constitutional articles (fixed).

---

## Practical Integration Steps

### 1. Directory Structure
```
project/
├── .claude/
│   ├── commands/           # claude-workflow commands
│   ├── skills/             # ai-software-architect skills
│   └── CLAUDE.md           # Combined guidance
├── .architecture/          # ai-software-architect artifacts
│   ├── decisions/adrs/
│   ├── reviews/
│   └── config.yml
├── specs/                  # spec-kit specifications
│   ├── constitution.md
│   ├── features/
│   └── plans/
└── .github/issues/         # GitHub Issues (claude-workflow)
```

### 2. CLAUDE.md Integration
Combine guidance from all three:
- spec-kit's constitutional principles
- ai-software-architect's methodology configuration
- claude-workflow's GitHub workflow instructions

### 3. Workflow Example: New Feature

1. **Check constitution** — Does this align with project principles?
2. **Specify** (`/speckit.specify`) — Define requirements, edge cases, acceptance criteria
3. **Architecture review** (`architecture-review`) — Get specialist perspectives
4. **Create ADR** (`create-adr`) — Document significant decisions
5. **Plan** (`/speckit.plan`) — Technical implementation approach
6. **Generate tasks** (`/speckit.tasks`) — Detailed breakdown
7. **Create Issues** (`/project:plan:tasks`) — Convert to GitHub Issues
8. **Implement** (`/project:do:task`) — Execute with PR linking

---

---

## Claude Code Baseline Capabilities

Before layering frameworks, understanding what Claude Code provides natively:

### Session Management
- **Sessions** are the primary unit (auto-persist, checkpoint every prompt)
- **`/resume`** — Interactive picker to switch between sessions
- **`/rename`** — Name sessions for easy discovery
- **`/rewind`** — Fork sessions to explore alternatives
- Sessions stored in `~/.claude/sessions/` (cleaned after 30 days)

### Plans Directory (`~/.claude/plans/`)
- **Not ephemeral** — Persistent markdown files with whimsical auto-names
- **Manual creation** — You (or Claude) create these intentionally
- **Working memory** — Decision journals, task breakdowns, implementation strategies
- **Global scope** — Per-user, not per-project

### Task Tracking
- **TodoWrite** exists but minimal — Simple list within a session
- **No cross-session task persistence** — Relies on sessions, plans, or CLAUDE.md
- **Implication**: External frameworks (like these three) fill this gap

### GitHub Integration
- **GitHub Actions** — `@claude` mentions in Issues/PRs trigger Claude
- **`/review`** — Request code review
- **`/security-review`** — Security analysis
- **Separate context** — GitHub interactions don't sync with terminal sessions

---

## GitHub Projects: The Missing Tracking Layer

GitHub Projects solves the "Issues doing heavy lifting" problem you identified:

### Architecture
- **Issues stay atomic** — Single, focused, reviewable pieces of work
- **Projects provide grouping** — Aggregation without bloating Issues
- **Sub-issues** (now GA) — Parent-child relationships up to 8 levels deep
- **Custom fields** — Up to 50 fields (priority, complexity, iteration, etc.)
- **Multiple views** — Table, Kanban, timeline/roadmap

### CLI Access (`gh project`)
```bash
gh project create --owner <owner> --title "Initiative Name"
gh project item-add <number> --owner <owner> --id <issue-id>
gh project item-edit <number> --id <item-id> --field-name "Status" --field-value "In Progress"
```
Requires: `gh auth refresh -s project` to add scope.

### Recommended Pattern
- **Parent Issue** = Initiative tracking document (e.g., "Implement authentication")
- **Sub-issues** = Atomic work items (e.g., "Build login UI", "Add OAuth")
- **Project** = Dashboard view with custom fields, charts, progress tracking

---

## Tiered Workflow Strategy

### Tier 1: Greenfield / Major Initiative
**Scope**: New project, major feature, architectural change

**Full workflow with permanent artifacts:**

```
1. CONSTITUTION (spec-kit)
   └─ /speckit.constitution — Establish immutable principles
   └─ Artifact: specs/constitution.md (version-controlled)

2. SPECIFICATION (spec-kit)
   └─ /speckit.specify — Requirements with edge cases
   └─ /speckit.clarify — Resolve ambiguities
   └─ Artifact: specs/features/<feature>.md

3. ARCHITECTURE (ai-software-architect)
   └─ architecture-review — Multi-perspective analysis
   └─ create-adr — Document decisions
   └─ Artifact: .architecture/decisions/adrs/

4. PLANNING (spec-kit)
   └─ /speckit.plan — Technical implementation
   └─ /speckit.tasks — Detailed breakdown
   └─ Artifact: specs/plans/<feature>-plan.md

5. TRACKING (GitHub)
   └─ Create parent Issue (initiative summary)
   └─ Create sub-issues (atomic tasks from step 4)
   └─ Create Project (aggregate view with custom fields)

6. IMPLEMENTATION
   └─ Work sub-issues individually
   └─ PRs reference and close sub-issues
   └─ Parent Issue tracks aggregate progress
```

**Artifacts produced:**
- `specs/constitution.md` — Project principles
- `specs/features/*.md` — Specifications
- `.architecture/decisions/adrs/*.md` — Decision records
- `specs/plans/*.md` — Implementation plans
- GitHub Project + Issues — Tracking

---

### Tier 2: Significant Feature (Established Codebase)
**Scope**: Non-trivial feature, multi-file change, requires design

**Medium workflow with selective artifacts:**

```
1. SPECIFICATION (spec-kit, lightweight)
   └─ /speckit.specify — Define scope and acceptance criteria
   └─ Artifact: Optional (keep in Issue description if simple)

2. ARCHITECTURE (ai-software-architect, if warranted)
   └─ specialist-review — Single specialist if needed (Security, Performance)
   └─ create-adr — Only for significant decisions
   └─ Artifact: ADR only if decision is reusable

3. PLANNING
   └─ Claude session plan file (~/.claude/plans/)
   └─ Or /speckit.tasks for complex breakdown

4. TRACKING (GitHub)
   └─ Create Issue (may have sub-issues if complex)
   └─ Add to existing Project if part of larger initiative

5. IMPLEMENTATION
   └─ Work from Issue
   └─ PR references Issue
```

**Artifacts produced:**
- Session plan (ephemeral working memory)
- ADR (only if significant decision)
- GitHub Issue(s)

---

### Tier 3: Small Change / Bug Fix
**Scope**: Single-file, well-defined, minimal design

**Lightweight workflow:**

```
1. ISSUE
   └─ Create GitHub Issue with clear description
   └─ Or work directly from existing Issue

2. IMPLEMENTATION
   └─ Direct coding with Claude
   └─ PR references and closes Issue

3. NO ARTIFACTS
   └─ Session history provides context
   └─ /resume if work spans sessions
```

**Artifacts produced:**
- GitHub Issue
- PR

---

## Issue Granularity Guidelines

### Issues Should Be:
- **Atomic** — Single reviewable piece of work
- **Closeable** — PR can definitively close it
- **Self-contained** — Includes acceptance criteria
- **Estimated** — Roughly 1-3 days of work maximum

### When an Issue Gets Too Big:
1. Convert to **parent Issue** (tracking document)
2. Break into **sub-issues** (atomic tasks)
3. Add to **GitHub Project** for aggregate tracking
4. Parent Issue closes when all sub-issues close

### Tracking Documents (Large Initiatives)
Use GitHub Projects, NOT giant Issues:
- Project description = initiative goals/scope
- Custom fields = metadata (priority, complexity, target date)
- Views = different stakeholder perspectives
- Charts = progress visualisation

---

## Tool Responsibility Matrix

| Domain | Primary Tool | Secondary | Artifacts |
|--------|--------------|-----------|-----------|
| **Principles/Constitution** | spec-kit | — | `specs/constitution.md` |
| **Requirements/Specs** | spec-kit | — | `specs/features/*.md` |
| **Architecture Decisions** | ai-software-architect | — | `.architecture/decisions/adrs/` |
| **Architecture Review** | ai-software-architect | — | `.architecture/reviews/` |
| **YAGNI Enforcement** | ai-software-architect | spec-kit (constitutional) | Config in `.architecture/` |
| **Implementation Planning** | spec-kit | Claude session plans | `specs/plans/` or `~/.claude/plans/` |
| **Task Breakdown** | spec-kit | claude-workflow | Issue sub-issues |
| **Issue Creation** | claude-workflow | Direct `gh` CLI | GitHub Issues |
| **Initiative Tracking** | GitHub Projects | — | Project dashboard |
| **Implementation** | Claude Code | claude-workflow `/project:do:task` | PRs |

---

## Integration Approach

### Directory Structure
```
project/
├── .claude/
│   ├── commands/           # claude-workflow (optional)
│   ├── skills/             # ai-software-architect skills
│   └── CLAUDE.md           # Combined guidance
├── .architecture/          # ai-software-architect
│   ├── decisions/adrs/
│   ├── reviews/
│   ├── config.yml
│   └── principles.md
├── specs/                  # spec-kit
│   ├── constitution.md
│   ├── features/
│   └── plans/
└── (GitHub Projects for tracking)
```

### CLAUDE.md Integration Points
Reference all three systems:
```markdown
## Workflow

### New Features (Tier 1-2)
1. Check specs/constitution.md for alignment
2. Use /speckit.specify for requirements
3. Use architecture-review for significant changes
4. Create ADRs for decisions
5. Break into GitHub Issues with sub-issues

### Small Changes (Tier 3)
1. Create/use GitHub Issue
2. Implement directly
3. PR closes Issue
```

---

## Recommended Next Steps

1. **Install all three frameworks** — They cover distinct lifecycle phases
2. **Configure GitHub Projects** — Set up a template Project structure
3. **Create CLAUDE.md guidance** — Document tiered workflow
4. **Test with real feature** — Run through Tier 1 or 2 workflow
5. **Refine based on friction** — Adjust tier thresholds and tool choices

---

## Open Questions Resolved

| Question | Resolution |
|----------|------------|
| Issue granularity | Keep atomic; use sub-issues and Projects for larger work |
| Claude Code plans | Working memory, not primary tracking; GitHub is permanent |
| Overlap handling | spec-kit for specs, ai-software-architect for architecture, claude-workflow for GitHub integration |
| Workflow flexibility | Three tiers based on scope; principles guide tier selection |

---

# Systems Architect Review: Framework Integration Plan

**Reviewer**: Dr. Sarah Chen, Systems Architect
**Target**: Three-framework integration strategy (spec-kit, ai-software-architect, claude-workflow)
**Date**: 2026-01-08
**Review Type**: Specialist Review

---

## Specialist Perspective

**Focus**: Overall system coherence, architectural patterns, component interaction, separation of concerns, and consistency of principles across the integrated workflow.

As Systems Architect, I evaluate whether the proposed integration creates a cohesive system where components work together harmoniously, or whether it introduces unnecessary coupling, redundancy, or friction.

---

## Executive Summary

The integration plan demonstrates solid architectural thinking with clear separation of concerns across lifecycle phases. The tiered workflow appropriately scales ceremony to complexity. However, several architectural concerns warrant attention before implementation.

**Overall Assessment**: Good

**Key Findings**:
1. Clear domain separation — each framework owns distinct lifecycle phases
2. Potential tight coupling between spec-kit artifacts and claude-workflow issue creation
3. Missing feedback loops — no mechanism for implementation learnings to update specifications
4. Cognitive load risk — three command namespaces may create friction

**Critical Actions Required**: 0 (no blockers, but 3 high-priority refinements)

---

## Current Implementation

**Scope Reviewed**:
- Five-layer integration architecture
- Three-tier workflow strategy
- Tool responsibility matrix
- Directory structure proposal
- Artifact lifecycle

**Pattern/Approach Used**: Layered architecture with phase-based tool delegation

---

## Assessment

### Strengths

1. **Clear Separation of Concerns**: Each framework owns a distinct domain — spec-kit for requirements, ai-software-architect for decisions, claude-workflow for tracking. This prevents responsibility confusion and allows each tool to evolve independently.

2. **Appropriate Abstraction Levels**: The tiered workflow correctly maps ceremony to complexity. Tier 3 (bug fixes) avoids unnecessary overhead while Tier 1 (greenfield) ensures thorough documentation for significant work.

3. **Single Source of Truth per Domain**: Specifications live in `specs/`, architecture decisions in `.architecture/`, tracking in GitHub. No artifact duplication across systems.

4. **Graceful Degradation**: Tiers allow partial adoption — teams can use Tier 3 workflow immediately and progressively adopt Tier 1/2 as needed. This reduces adoption friction.

5. **GitHub as Persistence Layer**: Choosing GitHub (Issues, Projects) as the permanent tracking system leverages existing infrastructure and provides visibility without introducing new tools.

### Concerns

1. **Artifact-to-Issue Coupling** (Severity: High)
   - **Issue**: The workflow assumes spec-kit tasks map cleanly to GitHub Issues, but no transformation mechanism is defined
   - **Location**: Tier 1 Step 5, Tier 2 Step 4
   - **Impact**: Manual transcription creates drift; automated sync creates tight coupling
   - **Fix**: Define explicit transformation rules or accept that specs and issues may diverge (with specs as authoritative)
   - **Effort**: Medium

2. **Missing Feedback Loops** (Severity: High)
   - **Issue**: No mechanism for implementation learnings to flow back to specifications
   - **Location**: Entire workflow — information flows downward only
   - **Impact**: Specifications become stale; "regeneration from specs" promise breaks down
   - **Fix**: Add explicit "retrospective" phase that updates specs based on implementation reality
   - **Effort**: Medium

3. **Command Namespace Fragmentation** (Severity: Medium)
   - **Issue**: Three different command styles: `/speckit.*`, `skill-name`, `/project:*`
   - **Location**: Tool Responsibility Matrix
   - **Impact**: Cognitive overhead; users must remember which namespace for which action
   - **Fix**: Consider unified command aliasing or clear decision tree documentation
   - **Effort**: Small

4. **Constitution vs Pragmatic Guard Overlap** (Severity: Medium)
   - **Issue**: Both spec-kit (constitutional articles) and ai-software-architect (Pragmatic Guard) enforce simplicity principles
   - **Location**: Overlap Analysis section
   - **Impact**: Conflicting enforcement or redundant checks
   - **Fix**: Designate ai-software-architect as authoritative for YAGNI enforcement; use spec-kit constitution for domain-specific principles only
   - **Effort**: Small

5. **Session Plan Ambiguity** (Severity: Low)
   - **Issue**: Tier 2 suggests "Claude session plan file" but these are global (~/.claude/plans/), not project-scoped
   - **Location**: Tier 2 Step 3
   - **Impact**: Plans for different projects intermingle; discovery difficult
   - **Fix**: For Tier 2 work, use project-local `specs/plans/` rather than global session plans
   - **Effort**: Small

### Observations

- **Implicit Ordering Assumption**: The five-layer diagram implies strict sequential flow, but real development often requires iteration between layers
- **GitHub Projects as Optional**: The plan mentions Projects but doesn't mandate them — this is appropriate for flexibility
- **MCP Server Gap**: claude-workflow mentions MCP servers, but integration plan doesn't address whether all three frameworks' MCP capabilities should be unified

---

## Recommendations

### Immediate (Before Implementation)

1. **Define Artifact Synchronisation Strategy**
   - **What**: Document whether spec-kit tasks → GitHub Issues is manual, semi-automated, or fully automated
   - **Why**: Prevents drift between specification artifacts and tracking system
   - **How**: Add "Artifact Sync" section to CLAUDE.md with explicit rules
   - **Effort**: Small
   - **Priority**: High

2. **Add Retrospective Phase to Tier 1**
   - **What**: After implementation, update specs based on what was actually built
   - **Why**: Maintains spec-to-code alignment; enables true regeneration capability
   - **How**: Add Step 7 to Tier 1: "Update specification with implementation learnings"
   - **Effort**: Small
   - **Priority**: High

3. **Clarify YAGNI Authority**
   - **What**: State explicitly that ai-software-architect Pragmatic Guard is authoritative for complexity challenges
   - **Why**: Prevents conflicting simplicity enforcement
   - **How**: Update Conflict Resolution section
   - **Effort**: Small
   - **Priority**: Medium

### Short-term (During Initial Adoption)

1. **Create Command Quick Reference**
   - **What**: Single-page cheat sheet mapping actions to commands across all three frameworks
   - **Why**: Reduces cognitive load of three namespaces
   - **How**: Table format: "I want to..." → "Use command..."
   - **Effort**: Small
   - **Priority**: Medium

2. **Establish Tier Selection Criteria**
   - **What**: Explicit decision tree for choosing workflow tier
   - **Why**: Removes ambiguity when starting new work
   - **How**: Flowchart or checklist: "New project? → Tier 1. Multi-file change? → Tier 2. Single-file fix? → Tier 3"
   - **Effort**: Small
   - **Priority**: Medium

### Long-term (After Initial Usage)

1. **Evaluate Command Unification**
   - **What**: Consider wrapper commands that abstract underlying framework differences
   - **Why**: Reduces cognitive load as workflow matures
   - **How**: Custom Claude skills that delegate to appropriate framework
   - **Effort**: Large
   - **Priority**: Low

2. **Consider Bidirectional Sync Tooling**
   - **What**: Automation to sync GitHub Issue updates back to spec artifacts
   - **Why**: Keeps specifications aligned with actual implementation
   - **How**: GitHub Actions or MCP server integration
   - **Effort**: Large
   - **Priority**: Low (only if drift becomes problem)

---

## Best Practices

1. **Loose Coupling Between Phases**: Artifacts from one phase should inform the next but not require tight programmatic integration. Human-in-the-loop at phase boundaries provides flexibility.

2. **Authoritative Source Principle**: For any piece of information, exactly one system should be authoritative. Others may reference but not duplicate.

3. **Progressive Disclosure**: Start with simplest workflow (Tier 3), adopt more ceremony only when complexity demands it.

**Industry Standards**:
- **C4 Model**: The layered approach aligns with C4's principle of appropriate abstraction levels
- **ADR Practices**: Using ai-software-architect for decisions follows industry-standard ADR patterns

---

## Risks

**If Recommendations Not Addressed**:

1. **Specification Drift** (Likelihood: High, Impact: Medium)
   - **Description**: Specs diverge from implementation; regeneration promise breaks
   - **Timeframe**: After 2-3 Tier 1 features without retrospective
   - **Impact**: Specifications become unreliable documentation
   - **Mitigation**: Implement retrospective phase

2. **Workflow Abandonment** (Likelihood: Medium, Impact: High)
   - **Description**: Cognitive overhead causes team to bypass formal workflow
   - **Timeframe**: Within first month of adoption
   - **Impact**: Investment in framework setup wasted
   - **Mitigation**: Command quick reference; start with Tier 3 only

3. **Tool Sprawl** (Likelihood: Low, Impact: Medium)
   - **Description**: Each framework adds features that overlap with others
   - **Timeframe**: 6+ months as frameworks evolve
   - **Impact**: Increasing redundancy and decision paralysis
   - **Mitigation**: Establish clear tool responsibility boundaries now

---

## Success Metrics

1. **Workflow Adherence**
   - **Current**: N/A (not yet implemented)
   - **Target**: >80% of Tier 1/2 work follows defined workflow
   - **How to Measure**: Presence of spec artifacts for significant features

2. **Specification Currency**
   - **Current**: N/A
   - **Target**: <2 week lag between implementation and spec update
   - **How to Measure**: Commit dates on spec files vs feature PRs

3. **Developer Friction**
   - **Current**: N/A
   - **Target**: <5 minutes to determine which tier/commands for new work
   - **How to Measure**: Self-reported during retrospectives

---

## Follow-up

**Re-Review Recommended**: After first Tier 1 feature completion

**Success Criteria for Closure**:
- [ ] Artifact sync strategy documented
- [ ] Retrospective phase added to Tier 1
- [ ] YAGNI authority clarified
- [ ] Command quick reference created

**Next Steps**:
1. Address High-priority recommendations before implementation
2. Install frameworks and validate directory structure
3. Run pilot with Tier 2 feature to test workflow

---

## Appendix

### Review Scope

**What Was Reviewed**:
- Integration plan document (`~/.claude/plans/flickering-wishing-key.md`)
- Framework purpose and capabilities (from earlier research)
- Proposed workflow and artifact structure

**What Was Not Reviewed**:
- Actual framework source code
- Real-world usage in production projects
- Performance characteristics of combined tooling

### Methodology

This review was conducted by analyzing:
- Architectural coherence of proposed integration
- Component coupling and separation of concerns
- Information flow and feedback loops
- Cognitive load and usability considerations

### References

**Standards Referenced**:
- C4 Model for software architecture
- ADR (Architectural Decision Records) best practices
- Specification-Driven Development principles

---

**Review Complete**

---

# Refinements Based on Specialist Reviews

**Synthesised from**: Systems Architect, Implementation Strategist, AI Engineer, Claude Code Specialist

This section incorporates recommendations from all four specialist reviews into actionable refinements.

---

## 1. Revised Tier 1 Workflow (with Retrospective)

The original Tier 1 workflow lacked a feedback loop. Updated:

```
1. CONSTITUTION (spec-kit)
   └─ /speckit.constitution — Establish immutable principles
   └─ Artifact: specs/constitution.md

2. SPECIFICATION (spec-kit)
   └─ /speckit.specify — Requirements with edge cases
   └─ /speckit.clarify — Resolve ambiguities
   └─ Artifact: specs/features/<feature>.md

3. ARCHITECTURE (ai-software-architect)
   └─ architecture-review — Multi-perspective analysis
   └─ create-adr — Document decisions
   └─ Artifact: .architecture/decisions/adrs/

4. PLANNING (spec-kit)
   └─ /speckit.plan — Technical implementation
   └─ /speckit.tasks — Detailed breakdown
   └─ Artifact: specs/plans/<feature>-plan.md

5. TRACKING (GitHub)
   └─ Create parent Issue (initiative summary)
   └─ Create sub-issues (atomic tasks)
   └─ Create Project (if multi-week initiative)

6. IMPLEMENTATION
   └─ Work sub-issues individually
   └─ PRs reference and close sub-issues
   └─ Use TodoWrite for in-session task tracking

7. RETROSPECTIVE (NEW)
   └─ Update specs/features/<feature>.md with implementation reality
   └─ Note any deviations from original spec
   └─ Update ADR if architectural decisions changed
   └─ Close parent Issue
   └─ Artifact: Updated spec + optional retrospective notes
```

**Rationale**: Enables spec regeneration capability; prevents specification drift.

---

## 2. Phased Pilot Approach

**Problem**: Installing all three frameworks simultaneously creates big-bang risk.

**Solution**: Incremental installation with validation gates.

### Phase 1: Claude-Workflow Only (Days 1-3)
**Goal**: Validate GitHub integration

**Install**:
- Copy `.claude/commands/` from claude-workflow

**Test with**:
- `/project:plan:tasks` on an existing feature idea
- Create GitHub Issue with structured description
- Close Issue via PR

**Success Criteria**:
- [ ] Issues created with correct labels
- [ ] PR linking works
- [ ] Workflow feels natural, not forced

**Rollback Trigger**: If Issue creation feels slower than manual, pause and reassess.

---

### Phase 2: Add ai-software-architect (Days 4-7)
**Goal**: Validate ADR and review workflow

**Install**:
- Run `setup-architect` skill
- Configure `.architecture/config.yml`

**Test with**:
- `create-adr` for a recent decision you made
- `specialist-review` on existing code (Security or Performance)

**Success Criteria**:
- [ ] ADR created in correct format
- [ ] Specialist review provides actionable insights
- [ ] Review findings are implementable

**Rollback Trigger**: If ADRs feel like busywork with no value, reduce scope to "significant decisions only".

---

### Phase 3: Add spec-kit (Days 8-14)
**Goal**: Validate specification-first workflow

**Install**:
- `specify init` or copy templates

**Test with**:
- `/speckit.specify` on a planned feature
- `/speckit.tasks` to break down into tasks

**Success Criteria**:
- [ ] Specification captures edge cases you hadn't considered
- [ ] Tasks map cleanly to GitHub Issues
- [ ] Spec-to-implementation flow feels productive

**Rollback Trigger**: If specs feel redundant to Issue descriptions, use spec-kit only for Tier 1 work.

---

### Phase 4: Full Integration Test (Days 15-21)
**Goal**: Run complete Tier 2 workflow end-to-end

**Test with**:
- Real feature using full workflow
- Track friction points

**Success Criteria**:
- [ ] Completed feature with spec, ADR (if needed), Issues, PR
- [ ] Retrospective phase executed
- [ ] Total overhead < 20% of implementation time

**Decision Point**:
- 🟢 **Green**: Adopt fully, document learnings
- 🟡 **Yellow**: Adjust tier thresholds, simplify where needed
- 🔴 **Red**: Revert to Tier 3-only workflow, reassess in 30 days

---

## 3. Session-to-Plan Handoff Protocol

**Problem**: No guidance for maintaining context across multi-day work.

**Solution**: Explicit session-plan mapping.

### For Tier 2 Work (Multi-Session Features)

**Starting a Feature**:
```
1. Create GitHub Issue first (permanent tracking)
2. Start Claude Code session
3. /rename "Feature-X: Phase"
4. Create plan file: ~/.claude/plans/feature-x.md
5. Link Issue URL in plan file header
```

**Ending a Session**:
```
1. Update plan file with:
   - Current progress
   - Next steps
   - Blockers
   - Session number
2. Update GitHub Issue with progress comment
3. Session auto-persists
```

**Resuming Work**:
```
1. /resume → Select "Feature-X: Phase" session
2. Read plan file for context refresh
3. Check GitHub Issue for any external updates
4. Continue work
```

### Plan File Template

```markdown
# Feature: [Name]

**GitHub Issue**: [URL]
**Tier**: 2
**Started**: [Date]

## Sessions

### Session 1 - [Date]
- **Phase**: Specification
- **Completed**: /speckit.specify
- **Output**: specs/features/feature-x.md
- **Next**: Architecture review

### Session 2 - [Date]
- **Phase**: Implementation
- **Completed**: [Tasks 1-3]
- **Blockers**: [Any blockers]
- **Next**: [Remaining tasks]

## Quick Context
[2-3 sentences summarising current state for fast resume]
```

---

## 4. Command Quick Reference

**Problem**: Three command namespaces create cognitive load.

**Solution**: "I want to..." decision table.

| I want to... | Use | Framework |
|--------------|-----|-----------|
| **Define project principles** | `/speckit.constitution` | spec-kit |
| **Write requirements/specs** | `/speckit.specify` | spec-kit |
| **Clarify ambiguous requirements** | `/speckit.clarify` | spec-kit |
| **Create implementation plan** | `/speckit.plan` | spec-kit |
| **Break work into tasks** | `/speckit.tasks` | spec-kit |
| **Document an architecture decision** | `create-adr` | ai-software-architect |
| **Get multi-perspective review** | `architecture-review` | ai-software-architect |
| **Get single specialist review** | `specialist-review` | ai-software-architect |
| **Challenge complexity (YAGNI)** | `pragmatic-guard` | ai-software-architect |
| **Check architecture health** | `architecture-status` | ai-software-architect |
| **Create GitHub Issues from tasks** | `/project:plan:tasks` | claude-workflow |
| **Execute a task with PR linking** | `/project:do:task` | claude-workflow |
| **See current project context** | `/project:current` | claude-workflow |
| **Review current PR** | `/review` | Claude Code native |
| **Security review** | `/security-review` | Claude Code native |
| **Resume previous session** | `/resume` | Claude Code native |
| **Track tasks this session** | TodoWrite | Claude Code native |

---

## 5. Tier Selection Decision Tree

**Problem**: Qualitative descriptions ("major feature", "non-trivial") cause inconsistent tier selection.

**Solution**: Measurable criteria.

```
START: What are you working on?
│
├─ Bug fix or typo?
│   └─ YES → Tier 3 (Issue → PR)
│
├─ Single file change?
│   └─ YES → Tier 3
│
├─ Estimated effort < 4 hours?
│   └─ YES → Tier 3
│
├─ Multi-file change, < 2 days effort?
│   └─ YES → Tier 2 (Issue → light spec optional → PR)
│
├─ New feature, 2-5 days effort?
│   └─ YES → Tier 2 (Issue → spec → plan → PR)
│
├─ Architectural decision required?
│   └─ YES → Tier 2 minimum (add ADR)
│
├─ New project or major subsystem?
│   └─ YES → Tier 1 (full workflow)
│
├─ Affects >5 files or >500 lines?
│   └─ YES → Tier 1 or Tier 2 with spec
│
├─ Multiple people involved?
│   └─ YES → Tier 1 or Tier 2 (specs enable handoff)
│
└─ Uncertain?
    └─ Start with Tier 2, escalate to Tier 1 if complexity grows
```

### Quick Heuristics

| Effort | Files | Tier |
|--------|-------|------|
| < 4 hours | 1-2 | Tier 3 |
| 4 hours - 2 days | 2-5 | Tier 2 (light) |
| 2-5 days | 5-15 | Tier 2 (full) |
| > 5 days | > 15 | Tier 1 |

---

## 6. AI Output Acceptance Criteria

**Problem**: No mechanism to evaluate AI-generated artifacts before they propagate downstream.

**Solution**: Quality checklists per artifact type.

### Specification Acceptance (spec-kit output)

Before proceeding to architecture phase:
- [ ] All user-facing features described
- [ ] Edge cases identified (minimum 3)
- [ ] Acceptance criteria are testable
- [ ] No implementation details in spec (what, not how)
- [ ] Scope is achievable (not gold-plated)

**If fails**: Run `/speckit.clarify` or manually refine.

### ADR Acceptance (ai-software-architect output)

Before proceeding to implementation:
- [ ] Decision is clearly stated
- [ ] Context explains why decision was needed
- [ ] Alternatives were considered (minimum 2)
- [ ] Consequences are realistic
- [ ] Decision aligns with project principles

**If fails**: Edit ADR manually or request revision.

### Task Breakdown Acceptance (spec-kit or claude-workflow output)

Before creating GitHub Issues:
- [ ] Each task is atomic (completable in < 1 day)
- [ ] Dependencies are identified
- [ ] No task requires decisions not yet made
- [ ] Tasks sum to spec scope (nothing missing, nothing extra)

**If fails**: Refine task breakdown manually.

### Architecture Review Acceptance

Before acting on recommendations:
- [ ] Recommendations are actionable (not vague)
- [ ] Severity ratings seem accurate
- [ ] No contradictions between specialists
- [ ] Effort estimates are plausible

**If contradictions exist**: Use ai-software-architect Pragmatic Guard as tiebreaker.

---

## 7. Expanded CLAUDE.md Template

**Problem**: Original template was skeletal; didn't address session scope, tool conflicts, or MCP requirements.

**Solution**: Comprehensive template.

```markdown
# Project: [Name]

## Workflow Tier

This project uses **Tier [1/2/3]** workflow by default.
- Escalate to higher tier if: [criteria]
- De-escalate if: [criteria]

## Command Priority

When in doubt about which command to use:

| Domain | Primary | Avoid |
|--------|---------|-------|
| Requirements | `/speckit.specify` | `/project:plan:prd` |
| Task breakdown | `/speckit.tasks` | — |
| Issue creation | `/project:plan:tasks` | Manual `gh issue create` |
| Architecture | `create-adr` | Inline comments |
| YAGNI enforcement | `pragmatic-guard` | — |

## Session Scope

- **Tier 3**: Single session per fix
- **Tier 2**: One primary session per feature; use `/rename` with feature name
- **Tier 1**: Session-per-phase recommended; bridge with plan files

### Multi-Session Work
1. Create plan file at `~/.claude/plans/[feature].md`
2. Link GitHub Issue in plan header
3. Update plan before ending session
4. Use `/resume` to return to named session

## GitHub Integration

- `/review` — Reviews current branch, updates session context
- `/security-review` — Security-focused review, updates session
- `@claude` mentions — Isolated GitHub context, does NOT sync to terminal
- **Recommendation**: Use `/review` for final validation before merge

## MCP Servers

Current configuration (check `~/.claude/settings.json`):
- `ruby-fetch` — URL fetching with FlareSolverr fallback

Framework requirements:
- spec-kit: [None / TBD after install]
- ai-software-architect: [None / TBD after install]
- claude-workflow: GitHub MCP recommended for enhanced integration

## Artifact Locations

| Artifact | Location | Authoritative? |
|----------|----------|----------------|
| Specifications | `specs/features/` | Yes |
| Implementation plans | `specs/plans/` | Yes |
| Constitution | `specs/constitution.md` | Yes |
| ADRs | `.architecture/decisions/adrs/` | Yes |
| Reviews | `.architecture/reviews/` | Reference only |
| Session plans | `~/.claude/plans/` | Working memory |
| Task tracking | GitHub Issues | Yes |
| Initiative tracking | GitHub Projects | Yes |

## Conflict Resolution

If frameworks give conflicting advice:
1. **YAGNI/Simplicity**: ai-software-architect Pragmatic Guard is authoritative
2. **Requirements**: spec-kit specification is authoritative
3. **Tracking**: GitHub is authoritative (Issues, Projects)
4. **Architecture**: ADR is authoritative once written

## Quality Gates

Before proceeding between phases, verify:
- [ ] Spec acceptance criteria met
- [ ] ADR acceptance criteria met (if applicable)
- [ ] Task breakdown acceptance criteria met
- [ ] No unresolved contradictions in AI output
```

---

## 8. Rollback Criteria

**Problem**: No explicit failure thresholds.

**Solution**: Red/yellow/green framework with specific triggers.

### Per-Framework Rollback Triggers

**claude-workflow**:
- 🔴 **Remove if**: Issue creation takes >5 minutes or feels bureaucratic
- 🟡 **Simplify if**: Labels/linking unused; revert to plain `gh issue create`
- 🟢 **Keep if**: Structured Issues improve PR review clarity

**ai-software-architect**:
- 🔴 **Remove if**: ADRs are never referenced after creation
- 🟡 **Simplify if**: Full architecture-review feels heavy; use specialist-review only
- 🟢 **Keep if**: ADRs prevent repeated debates; reviews catch real issues

**spec-kit**:
- 🔴 **Remove if**: Specs duplicate Issue descriptions with no added value
- 🟡 **Simplify if**: Use for Tier 1 only; skip for Tier 2
- 🟢 **Keep if**: Specs catch edge cases; enable regeneration

### Overall Workflow Rollback

If after 30 days:
- **> 50% of work bypasses defined workflow** → Workflow too heavy; simplify tier thresholds
- **Artifacts are stale within 2 weeks** → Retrospective phase not working; enforce or remove
- **Team reverts to ad-hoc Issues** → Value not demonstrated; run training or abandon

### Recovery Path

If rollback triggered:
1. Document what didn't work (retrospective)
2. Revert to simpler workflow (Tier 3 only)
3. Preserve valuable artifacts (ADRs, specs) as reference
4. Re-evaluate in 60 days with lessons learned

---

## 9. Claude Code Best Practices Summary

### Session Management
- `/rename` immediately when starting feature work
- One primary session per Tier 2 feature
- Use TodoWrite for in-session task tracking
- Plan files bridge sessions, GitHub Issues bridge days/weeks

### GitHub Sync Points
- Create Issue before or immediately after starting work
- Update Issue with progress comments (not just PR)
- Use `/review` for final PR validation
- `@claude` mentions are separate context — don't rely on them for session continuity

### Keyboard Shortcuts
- `Cmd+Shift+P` — Session picker (`/resume`)
- `Cmd+K` — Command palette
- `Cmd+L` — Clear session context
- `↑` — Previous command

### When to Create Plan Files
- Tier 2 work expected to span >1 session
- Complex decisions that need documentation
- Handoff to future self or collaborator
- NOT needed for Tier 3 work

---

## 10. Final Checklist Before Implementation

### Pre-Installation
- [ ] Read this entire plan
- [ ] Understand tier selection criteria
- [ ] Review command quick reference

### Phase 1 (claude-workflow)
- [ ] Install commands
- [ ] Test Issue creation
- [ ] Validate PR linking
- [ ] Document friction points

### Phase 2 (ai-software-architect)
- [ ] Run `setup-architect`
- [ ] Create test ADR
- [ ] Run specialist review
- [ ] Document friction points

### Phase 3 (spec-kit)
- [ ] Install templates
- [ ] Create test specification
- [ ] Generate task breakdown
- [ ] Document friction points

### Phase 4 (Integration)
- [ ] Run Tier 2 workflow end-to-end
- [ ] Execute retrospective phase
- [ ] Evaluate against success criteria
- [ ] Make go/adjust/no-go decision

### Post-Adoption
- [ ] CLAUDE.md configured per template
- [ ] Team trained on workflow (if applicable)
- [ ] 30-day review scheduled

---

## Summary of Changes from Original Plan

| Area | Original | Refined |
|------|----------|---------|
| Tier 1 workflow | 6 steps | 7 steps (added retrospective) |
| Installation | All at once | Phased pilot (4 phases) |
| Session handling | Mentioned but undefined | Explicit protocol with template |
| Command guidance | Tool matrix only | "I want to..." quick reference |
| Tier selection | Qualitative | Measurable decision tree |
| AI quality | Not addressed | Acceptance criteria per artifact |
| CLAUDE.md | Skeletal example | Comprehensive template |
| Failure handling | Not addressed | Rollback criteria with triggers |

---

**Specialist Reviews Incorporated**:
- Systems Architect: Feedback loops, YAGNI authority, loose coupling
- Implementation Strategist: Phased pilot, rollback criteria, tier thresholds
- AI Engineer: Quality evaluation, context budget awareness, conflict resolution
- Claude Code Specialist: Session protocol, TodoWrite, CLAUDE.md expansion, GitHub sync

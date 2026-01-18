# Skills Reference

User-level skills available across all projects. Invoke with `/skill-name` or natural language.

## Development Workflow

### `/worktree`

Creates git worktrees for parallel development—useful for running multiple Claude Code sessions on the same project without branch conflicts.

**Usage:**
```
/worktree                           # Detect context and suggest
/worktree <branch>                  # Worktree for specified branch
/worktree <branch> <path>           # Explicit branch and path
```

**Features:**
- Detects current branch and project path
- Generates semantic slugs from branch names (e.g., `feature/#1252_bootstrap-helper` → `-bootstrap`)
- Uses 80/20 confidence rule: ≥80% assume, 20-80% confirm, <20% prompt
- Runs dependency installation post-setup

**Allowed tools:** Bash, Read, AskUserQuestion

---

### `/read-email`

Fetches and displays emails from Gmail using OAuth credentials.

**Usage:**
```
/read-email                                    # Interactive
"check emails from support@example.com"        # Filter by sender
"find emails about invoice"                    # Search query
```

**Prerequisites:**
- `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` environment variables
- OAuth token at `~/.claude/gmail_token.yaml`

**Allowed tools:** Bash, Read

---

## AI Software Architect Framework

A suite of skills for managing architecture documentation, reviews, and decisions. Requires the framework to be set up in a project first.

### `/setup-architect`

Installs the AI Software Architect framework in a new project.

**Usage:**
```
/setup-architect
"Setup ai-software-architect"
"Initialize architecture framework"
```

**Process:**
1. Verifies prerequisites
2. Analyses project (languages, frameworks, patterns)
3. Installs framework files and directory structure
4. Customises team members for detected tech stack
5. Performs initial system analysis

**Allowed tools:** Read, Write, Edit, Glob, Grep, Bash

---

### `/architecture-status`

Reports on architecture documentation health—ADR counts, review activity, documentation gaps.

**Usage:**
```
/architecture-status
"What's our architecture status?"
"How many ADRs do we have?"
```

**Allowed tools:** Read, Glob, Grep

---

### `/list-members`

Displays the architecture team roster with specialties and expertise areas.

**Usage:**
```
/list-members
"Who's on the architecture team?"
"What specialists are available?"
```

**Allowed tools:** Read

---

### `/architecture-review`

Conducts a comprehensive multi-perspective review using ALL architecture team members.

**Usage:**
```
/architecture-review
"Start architecture review"
"Review architecture for version 2.0"
```

**Process:**
1. Determine scope (version, feature, or component)
2. Load team from `.architecture/members.yml`
3. Each member reviews from their perspective
4. Synthesise findings and establish priorities
5. Generate comprehensive review document

**Allowed tools:** Read, Write, Glob, Grep, Bash(git:*)

---

### `/specialist-review`

Conducts a focused review from ONE specific specialist's perspective.

**Usage:**
```
/specialist-review
"Ask Security Specialist to review authentication"
"Get Performance Expert's opinion on the API"
```

Use this for deep single-domain expertise. For multi-perspective reviews, use `/architecture-review`.

**Allowed tools:** Read, Write, Glob, Grep

---

### `/create-adr`

Creates a new Architectural Decision Record documenting a specific decision.

**Usage:**
```
/create-adr
"Create ADR for using PostgreSQL"
"Document decision about authentication approach"
```

**Captures:**
- What decision was made
- What problem it solves
- Alternatives considered
- Trade-offs and consequences

**Allowed tools:** Read, Write, Bash(ls:*, grep:*)

---

### `/pragmatic-guard`

Enables Pragmatic Guard Mode (YAGNI enforcement) to prevent over-engineering.

**Usage:**
```
/pragmatic-guard
"Enable pragmatic mode"
"Turn on YAGNI enforcement"
```

**Configures:**
- Intensity level (strict/balanced/lenient)
- Exemption categories
- Complexity triggers

**Allowed tools:** Read, Edit

---

## Related Documentation

- Git worktree guide: `~/.claude/docs/worktree-setup.md`
- Architecture framework: `~/.claude/skills/ARCHITECTURE.md`
- Skill patterns: `~/.claude/skills/_patterns.md`

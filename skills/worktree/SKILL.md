---
name: worktree
description: Creates a git worktree for parallel development. Use when the user asks to "create a worktree", "set up a worktree for <branch>", "make <branch> a worktree", or "/worktree". Enables running multiple Claude Code sessions on the same project without branch conflicts.
allowed-tools: Bash,Read,AskUserQuestion
---

# Worktree Setup Skill

Creates a git worktree for parallel development, particularly useful for running multiple Claude Code sessions on the same project without branch conflicts.

## Invocation

```
/worktree                           # Interactive - detect context and suggest
/worktree <branch>                  # Create worktree for specified branch
/worktree <branch> <path>           # Create worktree at explicit path
/worktree . <path>                  # Current branch at specified path
```

## Workflow

### Step 1: Gather Context

Run these commands to understand the current state:

```bash
# Current directory and git root
pwd
git rev-parse --show-toplevel

# Current branch
git branch --show-current

# Available local and remote branches
git branch -a --format='%(refname:short)'

# Existing worktrees
git worktree list
```

### Step 2: Determine Branch

**If branch specified:** Use it directly.

**If no branch specified:**
- If on a feature/bugfix branch (not master/main/develop): Use current branch (confidence: 90%)
- If on master/main/develop: Prompt user to specify branch (confidence: <20%)

### Step 3: Generate Path Slug

Parse the branch name to generate a short, memorable slug:

**Slug Generation Rules:**
1. Strip common prefixes: `feature/`, `bugfix/`, `fix/`, `hotfix/`, `docs/`, `chore/`, `refactor/`
2. Strip issue numbers: `#1234_`, `1234-`, `PROJ-123_`
3. Extract semantic keywords from remaining text
4. Combine 1-2 most distinctive words into slug (prefer nouns over verbs)
5. Keep slug short: 4-12 characters ideally

**Examples:**
| Branch Name | Slug | Reasoning |
|-------------|------|-----------|
| `feature/#1252_bootstrap-helper-abstraction` | `-bootstrap` | Key noun, distinctive |
| `feature/add_user_authentication` | `-auth` | Shortened keyword |
| `bugfix/#890_fix-nil-error-in-payments` | `-payments` | Domain area |
| `docs/20260118_worktree-setup-guide` | `-worktree` | Topic |
| `refactor/extract-service-objects` | `-services` | Pluralised keyword |
| `feature/#1300_add-dark-mode-toggle` | `-darkmode` | Combined keywords |

**Path Construction:**
```
<project-root>-<slug>
```

Example: `/opt/ruby/portfoliobuilder` + `-bootstrap` = `/opt/ruby/portfoliobuilder-bootstrap`

### Step 4: Confidence Assessment

Before proceeding, assess confidence in the inferred values:

| Confidence | Action |
|------------|--------|
| **≥80%** | State the plan clearly and proceed |
| **20-80%** | Suggest values and ask for confirmation |
| **<20%** | Ask user to specify |

**High confidence scenarios (≥80%):**
- User specified both branch and path explicitly
- On a feature branch, path generated from clear branch name
- Branch name contains obvious semantic keywords

**Medium confidence scenarios (20-80%):**
- Branch name is ambiguous or very short
- Generated slug might conflict with existing directory
- Multiple reasonable slug interpretations

**Low confidence scenarios (<20%):**
- On master/main/develop with no branch specified
- Branch name is cryptic (e.g., `wip`, `test`, `temp`)
- Project structure unclear

### Step 5: Verify Prerequisites

Before creating the worktree:

```bash
# Check if target path already exists
ls -la <target-path> 2>/dev/null

# Check if branch exists
git show-ref --verify refs/heads/<branch> 2>/dev/null || \
git show-ref --verify refs/remotes/origin/<branch> 2>/dev/null

# Check if branch is already checked out in another worktree
git worktree list | grep -q "<branch>"
```

**Handle issues:**
- Path exists: Suggest alternative or ask user
- Branch doesn't exist: Offer to create it
- Branch already in worktree: Inform user and show where

### Step 6: Create Worktree

```bash
# For existing branch
git worktree add <target-path> <branch>

# For new branch (if user requested)
git worktree add -b <new-branch> <target-path>
```

### Step 7: Setup Worktree Environment

After creating the worktree, detect and run appropriate setup:

```bash
cd <target-path>

# Detect project type and install dependencies
if [ -f "Gemfile" ]; then
    bundle install
elif [ -f "package.json" ]; then
    npm install  # or yarn/pnpm based on lockfile
elif [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
elif [ -f "go.mod" ]; then
    go mod download
fi
```

### Step 8: Report Success

Provide a summary:

```
✓ Worktree created successfully

  Branch: feature/#1252_bootstrap-helper-abstraction
  Path:   /opt/ruby/portfoliobuilder-bootstrap

  To work in this worktree:
    cd /opt/ruby/portfoliobuilder-bootstrap

  To start a Claude session:
    cd /opt/ruby/portfoliobuilder-bootstrap && claude

  To remove when done:
    git worktree remove /opt/ruby/portfoliobuilder-bootstrap
```

## Database Considerations

If the project appears to be a Rails/database-backed application, mention:

- For same-schema work: Databases are shared, no action needed
- For schema-divergent work (e.g., upgrades): May need separate database config

Refer to `~/.claude/docs/worktree-setup.md` for detailed database isolation instructions if needed.

## Error Handling

| Error | Resolution |
|-------|------------|
| "already checked out" | Show where, suggest removing that worktree first |
| Path exists | Suggest alternative path with `-2` suffix or different slug |
| Branch not found | Offer to create new branch or list similar branches |
| Dirty working tree | Warn but proceed (worktrees don't require clean state) |

## Examples

**Explicit usage:**
```
User: /worktree feature/#1300_dark-mode /opt/ruby/myapp-dark
→ Creates worktree at specified path for specified branch
```

**Context-aware usage:**
```
User: /worktree
(Currently on feature/#1252_bootstrap-helper-abstraction in /opt/ruby/portfoliobuilder)
→ "I'll create a worktree for your current branch:
   Branch: feature/#1252_bootstrap-helper-abstraction
   Path: /opt/ruby/portfoliobuilder-bootstrap

   Proceed?"
```

**Partial specification:**
```
User: /worktree feature/#999_payment-refactor
(In /opt/ruby/myapp)
→ "I'll create a worktree:
   Branch: feature/#999_payment-refactor
   Path: /opt/ruby/myapp-payments

   Proceed?"
```

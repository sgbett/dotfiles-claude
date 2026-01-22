# Create Project Worktree

Creates a git worktree with a "working master" branch for project isolation. This enables running multiple Claude Code sessions on the same project without branch conflicts, with proper PR targeting for long-running feature work.

**Task:** Create project worktree for: $ARGUMENTS

## Step 1: Gather Context

**Run these commands to understand the current state:**

```bash
# Current directory and git root
pwd
git rev-parse --show-toplevel

# Current branch
git branch --show-current

# Project name (basename of git root)
basename $(git rev-parse --show-toplevel)

# Existing worktrees
git worktree list

# Check for plan file with issue number
ls -t .claude/plans/*.md 2>/dev/null | head -1
```

**If a plan file exists, extract the issue number:**
```bash
# Look for **Issue**: #1234 pattern in the most recent plan
grep -oE '\*\*Issue\*\*:?\s*#?([0-9]+)' "$(ls -t .claude/plans/*.md 2>/dev/null | head -1)" | grep -oE '[0-9]+' | head -1
```

## Step 2: Parse Arguments and Determine Branch

**Parse the input argument ($ARGUMENTS):**

1. **If empty**: Try to infer from current plan or ask user
2. **If issue number** (e.g., `#1252` or `1252`): Fetch issue title from GitHub
3. **If branch prefix** (e.g., `feature/#1252_bootstrap`): Use directly

**Generate working master branch name:**
```
{type}/#{issue}_{slug}/master
```

**Slug generation from issue title:**
1. Lowercase the title
2. Replace spaces with hyphens
3. Remove non-alphanumeric characters (except hyphens)
4. Truncate to 30 characters

**Example:**
- Issue #1252: "Bootstrap Helper Abstraction"
- Slug: `bootstrap-helper-abstraction`
- Working master: `feature/#1252_bootstrap-helper-abstraction/master`

**Fetch issue title if needed:**
```bash
gh api repos/{owner}/{repo}/issues/{issue_number} --jq '.title'
```

## Step 3: Generate Worktree Path

**Path convention:**
```
{project-root}-worktrees/{branch-prefix-with-slashes-as-dashes}
```

**Conversion rules:**
1. Take the branch prefix (without `/master`)
2. Replace all `/` with `-`

**Example:**
- Git root: `/opt/ruby/portfoliobuilder`
- Branch prefix: `feature/#1252_bootstrap-helper-abstraction`
- Worktree path: `/opt/ruby/portfoliobuilder-worktrees/feature-#1252_bootstrap-helper-abstraction`

## Step 4: Assess Confidence

| Confidence | Scenario | Action |
|------------|----------|--------|
| **>=80%** | Issue number provided or found in plan | State plan clearly and proceed |
| **20-80%** | Branch name inferred from context | Suggest values and ask for confirmation |
| **<20%** | On master/main with no context | Ask user to specify issue number |

**High confidence scenarios:**
- User provided explicit issue number or branch prefix
- Plan file contains issue number
- Current branch matches `feature/#N_*` pattern

**Low confidence scenarios:**
- On master/main/develop with no plan
- No arguments provided and no plan found
- Branch name is ambiguous

## Step 5: Verify Prerequisites

**Check before proceeding:**

```bash
# Check if worktree path already exists
if [ -d "$WORKTREE_PATH" ]; then
    echo "Path already exists: $WORKTREE_PATH"
    # Offer: use existing, remove and recreate, or cancel
fi

# Check if branch is already checked out elsewhere
if git worktree list | grep -q "$WORKING_MASTER"; then
    echo "Branch already in use:"
    git worktree list | grep "$WORKING_MASTER"
fi

# Check if branch exists
git show-ref --verify refs/heads/"$WORKING_MASTER" 2>/dev/null
```

## Step 6: Create Worktree

**Create the worktree directory and branch:**

```bash
# Create parent directory if needed
mkdir -p "$(dirname "$WORKTREE_PATH")"

# Create worktree
if [ "$BRANCH_EXISTS" = true ]; then
    # Branch exists - check it out
    git worktree add "$WORKTREE_PATH" "$WORKING_MASTER"
else
    # Branch doesn't exist - create from master
    git worktree add -b "$WORKING_MASTER" "$WORKTREE_PATH" master
fi
```

## Step 7: Setup Worktree Environment

**Install dependencies in the new worktree:**

```bash
cd "$WORKTREE_PATH"

# Ruby/Rails
if [ -f "Gemfile" ]; then
    bundle install
fi

# Node.js
if [ -f "package.json" ]; then
    npm install  # or yarn/pnpm based on lockfile
fi
```

## Step 8: Push Working Master to Upstream

**Push the branch so PRs can target it:**

```bash
git push upstream "$WORKING_MASTER"
```

**Note:** This requires upstream write access. If push fails, inform user they'll need to push manually or use origin.

## Step 9: Report Success

**Provide comprehensive summary:**

```
Worktree created successfully

  Working Master: {working_master_branch}
  Path:           {worktree_path}

  To work in this worktree:
    cd {worktree_path}

  To start a Claude Code session:
    cd {worktree_path} && claude

Creating Task Branches
----------------------
When starting work on a task (e.g., #{task_issue}):

    git checkout -b {branch_prefix}/#{task_issue}_{task-slug}

Set PR target to working master:
    git config branch."{task_branch}".gh-merge-base "{working_master_branch}"

Create PR (will automatically target working master):
    git push -u origin {task_branch}
    gh pr create

Merging to Working Master
-------------------------
After PR is merged to working master, sync:
    git checkout {working_master_branch}
    git pull upstream {working_master_branch}

To remove worktree when project complete:
    git worktree remove {worktree_path}
```

## Error Handling

| Error | Resolution |
|-------|------------|
| "already checked out" | Show where, suggest removing that worktree first |
| Path exists | Suggest alternative or offer to use existing |
| Branch not found | Offer to create new branch from master |
| Push failed | Inform user to push manually; continue with worktree creation |
| No issue found | Ask user to provide issue number |

## Examples

**With issue number:**
```
User: /project:worktree #1252

Worktree created successfully

  Working Master: feature/#1252_bootstrap-helper-abstraction/master
  Path:           /opt/ruby/portfoliobuilder-worktrees/feature-#1252_bootstrap-helper-abstraction
```

**With explicit branch:**
```
User: /project:worktree feature/#1113_staging-environment

Worktree created successfully

  Working Master: feature/#1113_staging-environment/master
  Path:           /opt/ruby/portfoliobuilder-worktrees/feature-#1113_staging-environment
```

**Inferred from plan:**
```
User: /project:worktree
(Plan contains **Issue**: #1300)

I found issue #1300 in your plan. I'll create a worktree for it.

Worktree created successfully

  Working Master: feature/#1300_dark-mode-toggle/master
  Path:           /opt/ruby/portfoliobuilder-worktrees/feature-#1300_dark-mode-toggle
```

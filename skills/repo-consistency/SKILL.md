---
name: repo-consistency
description: Checks documentation consistency across the repository. Use when user asks to "check consistency", "are the documents consistent", "is everything aligned", "verify documentation", or "/repo-consistency".
allowed-tools: Bash,Read,Glob,Grep,Write,Edit,AskUserQuestion
---

# Repository Consistency Check

Scans documentation files across the repository to ensure they are internally consistent and aligned with each other.

## Invocation

```
/repo-consistency
"check the consistency of the repo"
"are the documents consistent"
"is everything aligned"
"verify documentation"
"check docs are up to date"
```

## Scope

### Files to Check

| Location | Type | Priority |
|----------|------|----------|
| `./*.md` | Root documentation | Primary (can edit) |
| `docs/*.md` | Reference documentation | Primary (can edit) |
| `playbooks/*.md` | Procedures | Primary (can edit) |
| `SKILLS.md` | Skills reference | Primary (can edit) |
| `skills/*/SKILL.md` | Skill definitions | Secondary (source of truth for skills) |
| `commands/*.md` | Command definitions | Secondary (source of truth for commands) |
| `speckit/**/*.md` | Spec-kit templates | Contributed (prefer not to edit) |
| `mcp/**/*.md` | MCP server docs | Secondary |

### Third-Party / Contributed Content

These directories may contain content from external repositories. When conflicts arise, **prefer fixing local documentation** rather than modifying contributed files:

- `speckit/` — from spec-kit
- `skills/architecture-*`, `skills/specialist-*`, `skills/create-adr`, `skills/list-members`, `skills/pragmatic-guard`, `skills/setup-architect` — from ai-software-architect
- `commands/project/` — from claude-workflow

## Consistency Checks

### 1. Cross-Reference Validity

Check that references between files are valid:

```
# Find all internal references
grep -rE "\`~?/?\.?claude/[^'\"]+\`" *.md docs/*.md playbooks/*.md

# Find all skill references
grep -rE "/[a-z-]+" *.md docs/*.md playbooks/*.md | grep -v "http"
```

**Check:**
- File paths exist (e.g., `~/.claude/docs/worktree-setup.md`)
- Skill names exist (e.g., `/repo-security-scan`)
- Command names exist (e.g., `/dotfiles-setup`)

**Report invalid references:**
```
[BROKEN] README.md:42 references `~/.claude/docs/old-guide.md` (file not found)
[BROKEN] SKILLS.md:87 references `/old-skill` (skill not found)
```

### 2. Skills Documentation Sync

Compare `SKILLS.md` against actual skills:

```bash
# List documented skills in SKILLS.md
grep -E "^### \`/" SKILLS.md | sed 's/.*`\/\([^`]*\)`.*/\1/'

# List actual skills
ls -d skills/*/SKILL.md | xargs -I{} dirname {} | xargs -n1 basename
```

**Check:**
- All skills in `skills/*/SKILL.md` are documented in `SKILLS.md`
- No skills documented in `SKILLS.md` that don't exist
- Descriptions match between `SKILLS.md` and individual `SKILL.md` files
- Allowed tools listed correctly

**Report discrepancies:**
```
[MISSING] Skill /repo-consistency exists but not documented in SKILLS.md
[STALE] Skill /old-skill documented in SKILLS.md but directory not found
[MISMATCH] /worktree description differs between SKILLS.md and SKILL.md
```

### 3. Commands Documentation Sync

Check commands are properly documented:

```bash
# List actual commands
find commands -name "*.md" -type f | sed 's|commands/||;s|\.md$||'
```

**Check:**
- Commands have consistent naming
- README or SKILLS.md mentions available commands

### 4. Setup Documentation Accuracy

Verify `SETUP.md` accurately reflects repo contents:

```bash
# What SETUP.md says gets installed
grep -A 20 "What gets installed" SETUP.md

# What actually exists
ls -la *.md
ls -d */ 2>/dev/null
```

**Check:**
- All items listed in "What gets installed" exist
- No major items missing from the list
- `.gitignore` entries match "What gets preserved"

### 5. README Accuracy

Verify `README.md` is current:

**Check:**
- Directory structure matches description
- Setup instructions point to correct files
- Links are valid

### 6. Naming Conventions

Check consistent naming across documentation:

**Check:**
- Skill names use kebab-case (`repo-security-scan` not `repoSecurityScan`)
- File names follow conventions
- British English spelling where applicable (behaviour, colour, organisation)

### 7. Duplicate Information

Identify content that's duplicated and might drift:

**Check:**
- Same procedure documented in multiple places
- Configuration examples duplicated
- Potential for one to be updated without the other

### 8. Orphaned Files

Find documentation that isn't referenced anywhere:

```bash
# List all .md files
find . -name "*.md" -type f | grep -v node_modules

# Check which are referenced
for f in $(find docs -name "*.md"); do
  basename=$(basename "$f")
  grep -r "$basename" --include="*.md" . | grep -v "^$f:" || echo "[ORPHAN] $f"
done
```

## Workflow

### Step 1: Gather All Documentation

```bash
# Collect all markdown files
find . -name "*.md" -type f | grep -v node_modules | grep -v .git

# Build inventory
- Root: CLAUDE.md, README.md, SETUP.md, SKILLS.md, CONTRIBUTING.md, etc.
- docs/: spotlight.md, worktree-setup.md, etc.
- playbooks/: workflow-guide.md, etc.
- skills/: SKILL.md files
- commands/: command definitions
```

### Step 2: Run Consistency Checks

Execute each check category and collect findings.

### Step 3: Categorise Findings

| Severity | Meaning |
|----------|---------|
| **Error** | Broken reference, missing required content |
| **Warning** | Outdated info, mismatch between files |
| **Info** | Suggestion for improvement, minor inconsistency |

### Step 4: Generate Report

Write findings to console (and optionally `consistency-report.md`):

```markdown
# Repository Consistency Report

**Date:** YYYY-MM-DD
**Files scanned:** 42

## Summary

| Severity | Count |
|----------|-------|
| Errors   | 2     |
| Warnings | 5     |
| Info     | 3     |

## Findings

### Errors

#### [E1] Broken reference in README.md
- **File:** README.md:42
- **Issue:** References `~/.claude/docs/old-guide.md` which doesn't exist
- **Fix:** Update reference or create the file

#### [E2] Missing skill documentation
- **File:** SKILLS.md
- **Issue:** Skill `/repo-consistency` exists but not documented
- **Fix:** Add section to SKILLS.md

### Warnings

#### [W1] Description mismatch
- **Files:** SKILLS.md:15, skills/worktree/SKILL.md:3
- **Issue:** Skill descriptions don't match
- **SKILLS.md says:** "Creates git worktrees for parallel development"
- **SKILL.md says:** "Creates a git worktree for parallel development"
- **Fix:** Align descriptions (update SKILLS.md to match SKILL.md)

### Info

#### [I1] Potential duplicate content
- **Files:** SETUP.md, README.md
- **Issue:** Setup instructions appear in both files
- **Suggestion:** Consider single source of truth with cross-reference

## Recommendations

1. Fix all Errors immediately
2. Address Warnings to prevent drift
3. Consider Info items for future cleanup
```

### Step 5: Offer Fixes

For issues that can be auto-fixed:

```
Found 2 errors and 5 warnings.

Auto-fixable issues:
  [E2] Add /repo-consistency to SKILLS.md
  [W1] Align description in SKILLS.md

Would you like me to fix these automatically?
  - Fix all
  - Fix errors only
  - Review each
  - Skip (just report)
```

### Step 6: Apply Fixes (if requested)

When fixing, follow the priority:

1. **Update local docs** (README.md, SKILLS.md, SETUP.md, docs/*.md)
2. **Leave contributed files unchanged** (speckit/, ai-software-architect skills)
3. **Update skill/command source only if it's clearly wrong**

## Examples

### Missing Skill Documentation

**Found:** `skills/repo-consistency/SKILL.md` exists but not in `SKILLS.md`

**Fix:** Add to SKILLS.md:
```markdown
### `/repo-consistency`

Checks documentation consistency across the repository.

**Usage:**
...
```

### Broken File Reference

**Found:** `playbooks/development-workflow.md` references `docs/git-workflow.md` which doesn't exist

**Fix options:**
1. Create the missing file
2. Update the reference to correct path
3. Remove the reference if obsolete

### Stale Setup Instructions

**Found:** `SETUP.md` lists `specs/` in "What gets installed" but `specs/` is now gitignored

**Fix:** Remove `specs/` from the "What gets installed" table

## Notes

- Run after making significant documentation changes
- Run before committing documentation updates
- Helps maintain documentation quality over time
- Does not modify files without explicit permission

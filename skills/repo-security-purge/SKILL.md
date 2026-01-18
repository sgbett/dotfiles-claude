---
name: repo-security-purge
description: Rewrites git history to permanently remove sensitive data. DESTRUCTIVE OPERATION - rewrites commit history. Use when user asks to "purge secrets from history", "remove sensitive data from git history", "clean git history", or "/repo-security-purge". Requires explicit confirmation.
allowed-tools: Bash,Read,Write,Glob,Grep,AskUserQuestion
---

# Repository Security Purge

Permanently removes sensitive data from git history using `git-filter-repo`. This is a **DESTRUCTIVE** operation that rewrites commit history.

## ⚠️ DANGER ZONE ⚠️

This skill:
- **Rewrites git history** — all commit hashes will change
- **Requires force push** — will break other clones/forks
- **Is irreversible** — cannot be undone after force push
- **Affects all branches** — entire repository history is rewritten

## Invocation

```
/repo-security-purge
"purge secrets from git history"
"remove sensitive data from history"
"clean the git history"
```

## Prerequisites

### git-filter-repo

Check if installed:
```bash
git-filter-repo --version
```

If not installed:
```bash
# macOS
brew install git-filter-repo

# pip
pip install git-filter-repo

# Linux
apt install git-filter-repo  # or package manager equivalent
```

### Fresh Clone Recommended

`git-filter-repo` works best on a fresh clone:
```bash
git clone --mirror <repo-url> repo-mirror
cd repo-mirror
```

## Workflow

### Step 1: Verify Prerequisites

```bash
# Check git-filter-repo is installed
git-filter-repo --version

# Check we're in a git repo
git rev-parse --is-inside-work-tree

# Check for uncommitted changes
git status --porcelain
```

**If uncommitted changes exist:** Stop and ask user to commit or stash first.

**If git-filter-repo not installed:** Provide installation instructions and stop.

### Step 2: Get Security Scan with History

This skill depends on `/repo-security-scan --history` for findings. Check for an existing scan:

```bash
# Look for today's scan report
ls -t security/*-scan.md 2>/dev/null | head -1
```

**If recent scan exists (today):**
- Read the report
- Check if it includes history findings (look for "History scanned: Yes")
- If history was scanned, use this report
- If history was NOT scanned, need to re-run with history

**If no recent scan OR history not scanned:**
- Inform user: "Running security scan with history to identify items to purge..."
- Invoke `/repo-security-scan --history`
- Wait for scan to complete
- Read the generated report

### Step 3: Parse Scan Report for History Items

Read the scan report and extract items marked as "History" or "HISTORY":

```
From scan report, extract:
- Files to remove (marked as History - e.g., "certs/server.key (HISTORY)")
- Patterns to scrub (secrets found in history)
- Commit references where secrets were introduced
```

Build a purge list from the report's history findings.

**If no history findings:**
```
No secrets found in git history.

Current file issues (if any) can be fixed with /repo-security-clean.
Nothing to purge from history.
```
Exit gracefully.

### Step 4: Identify Items to Purge

Build a list of:

1. **Files to remove entirely:**
   - Private keys (`.pem`, `.key`)
   - Credential files (`.env`, `credentials.json`)
   - Certificates with keys (`.p12`, `.pfx`)

2. **Patterns to scrub from content:**
   - Specific API keys/tokens
   - Passwords
   - Connection strings

Present findings:
```
Secrets found in git history:

Files to remove:
  - certs/server.key (added in abc123, 15 commits ago)
  - config/.env (added in def456, 42 commits ago)
  - secrets/credentials.json (removed in ghi789, but still in history)

Patterns to scrub:
  - API key "sk-abc123..." found in 3 commits
  - Password "hunter2" found in 2 commits
```

### Step 5: LOUD WARNING

Display prominent warning:

```
╔══════════════════════════════════════════════════════════════════╗
║                    ⚠️  DESTRUCTIVE OPERATION ⚠️                    ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  You are about to REWRITE GIT HISTORY.                          ║
║                                                                  ║
║  This will:                                                      ║
║    • Change ALL commit hashes in the repository                  ║
║    • Break existing clones, forks, and pull requests             ║
║    • Require FORCE PUSH to update remote                         ║
║    • Be IRREVERSIBLE after force push                            ║
║                                                                  ║
║  Items to purge:                                                 ║
║    • 3 files (certs/server.key, config/.env, ...)               ║
║    • 2 secret patterns                                           ║
║                                                                  ║
║  Affected:                                                       ║
║    • 847 commits will be rewritten                               ║
║    • All branches and tags                                       ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

### Step 6: Require Explicit Confirmation

**Do not proceed with a simple yes/no.** Require the user to type a specific phrase:

```
To proceed, type exactly: PURGE HISTORY

> _
```

Only continue if input matches exactly `PURGE HISTORY`.

If user types anything else, abort:
```
Aborted. No changes made.

To clean secrets without rewriting history, use /repo-security-clean instead.
```

### Step 7: Create Backup

Before purging, create a backup:

```bash
# Create a backup branch/tag
git tag backup-before-purge-$(date +%Y%m%d)

# Or create full backup
git clone --mirror . ../repo-backup-$(date +%Y%m%d)
```

Inform user:
```
Backup created: ../repo-backup-20260118

If something goes wrong, you can restore from this backup.
```

### Step 8: Execute Purge

#### Remove Files Entirely

```bash
# Remove specific files from all history
git-filter-repo --invert-paths --path certs/server.key --path config/.env

# Remove by pattern
git-filter-repo --invert-paths --path-glob '*.pem' --path-glob '*.key'
```

#### Scrub Sensitive Content

Create a replacements file (`replacements.txt`):
```
sk-abc123def456ghi789jkl012mno345pqr678==>[REDACTED_API_KEY]
hunter2==>[REDACTED_PASSWORD]
mongodb://user:pass@host:27017/db==>mongodb://[REDACTED]@host:27017/db
```

Apply replacements:
```bash
git-filter-repo --replace-text replacements.txt
```

#### Remove Large Files (bonus)

```bash
# Remove files larger than 10MB from history
git-filter-repo --strip-blobs-bigger-than 10M
```

### Step 9: Verify Purge

```bash
# Verify secrets are gone
git log -p --all | grep -E "(sk-abc123|hunter2)" || echo "✓ Secrets removed"

# Check file is gone from all history
git log --all --full-history -- certs/server.key || echo "✓ File purged"

# Run security scan again
# (invoke /repo-security-scan --history)
```

### Step 10: Post-Purge Instructions

```
╔══════════════════════════════════════════════════════════════════╗
║                     ✓ HISTORY REWRITTEN                          ║
╚══════════════════════════════════════════════════════════════════╝

Purged from history:
  ✓ certs/server.key
  ✓ config/.env
  ✓ secrets/credentials.json
  ✓ 2 secret patterns scrubbed

Backup location: ../repo-backup-20260118

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️  REQUIRED NEXT STEPS:

1. ROTATE ALL EXPOSED CREDENTIALS
   The secrets were public. Assume they are compromised.
   - [ ] Rotate API key sk-abc123...
   - [ ] Change password for database
   - [ ] Revoke and regenerate any tokens

2. FORCE PUSH TO REMOTE
   ⚠️  This will break existing clones and forks!

   git push --force --all origin
   git push --force --tags origin

3. NOTIFY COLLABORATORS
   All team members must re-clone or run:

   git fetch origin
   git reset --hard origin/master

4. UPDATE FORKS (if applicable)
   Fork owners need to sync with upstream.

5. CLEAN UP BACKUPS
   After verifying everything works:

   rm -rf ../repo-backup-20260118
   git tag -d backup-before-purge-20260118

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Report saved: security/YYYYMMDD-purge.md
```

### Step 11: Generate Report

Write to `security/YYYYMMDD-purge.md`:

```markdown
# Security Purge Report

**Repository:** <repo-name>
**Date:** YYYY-MM-DD HH:MM
**Operation:** Git history rewrite

## ⚠️ Destructive Operation Completed

This report documents a git history rewrite operation.

## Items Purged

### Files Removed from History

| File | Originally Added | Commits Affected |
|------|------------------|------------------|
| certs/server.key | abc1234 | 15 |
| config/.env | def5678 | 42 |
| secrets/credentials.json | ghi9012 | 8 |

### Patterns Scrubbed

| Pattern | Replacement | Occurrences |
|---------|-------------|-------------|
| sk-abc123... | [REDACTED_API_KEY] | 3 |
| hunter2 | [REDACTED_PASSWORD] | 2 |

## Statistics

- Commits rewritten: 847
- Branches affected: 5
- Tags affected: 12

## Backup

Location: `../repo-backup-20260118`

## Required Actions

- [ ] Rotate all exposed credentials
- [ ] Force push to remote
- [ ] Notify collaborators
- [ ] Clean up backup after verification

## Verification

```bash
# Verify purge was successful
git log -p --all | grep "sk-abc123" # Should return nothing
```
```

## Error Handling

| Error | Resolution |
|-------|------------|
| git-filter-repo not installed | Provide installation instructions |
| Uncommitted changes | Ask user to commit or stash |
| Not a git repository | Abort with message |
| Protected branch on remote | Warn about force push restrictions |
| Confirmation not matched | Abort, no changes made |

## Alternatives

If history rewrite is too disruptive:

1. **Accept the exposure** — rotate credentials, add to .gitignore going forward
2. **Create fresh repo** — copy current files to new repo, lose history
3. **Use BFG Repo-Cleaner** — alternative tool, similar results

## Safety Notes

- This skill will **NEVER** force push automatically
- This skill will **NEVER** proceed without explicit typed confirmation
- This skill will **ALWAYS** create a backup first
- This skill will **ALWAYS** warn about collaborator impact

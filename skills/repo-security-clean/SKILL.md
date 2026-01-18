---
name: repo-security-clean
description: Scans repository for security issues and automatically remediates them. Use when the user asks to "clean up security issues", "fix security problems", "remove sensitive data", "sanitise the repo", or "/repo-security-clean". More aggressive than /repo-security-scan - this skill takes action.
allowed-tools: Bash,Read,Write,Edit,Glob,Grep,AskUserQuestion
---

# Repository Security Clean

Scans the repository for security issues and automatically remediates them. This is the action-oriented companion to `/repo-security-scan`.

## Invocation

```
/repo-security-clean
"clean up security issues"
"fix the security problems"
"remove sensitive data from the repo"
"sanitise this repository"
```

## Prerequisites

First run `/repo-security-scan` to generate a report, OR this skill will run a scan first.

## Workflow

### Step 1: Check for Existing Scan

Look for recent scan report:
```bash
ls -t security/*-scan.md 2>/dev/null | head -1
```

**If scan exists from today:** Use it
**If no recent scan:** Run `/repo-security-scan` first

### Step 2: Parse Findings

Read the scan report and extract actionable items (High and Medium priority).

Build a remediation queue:
```
[H1] Hardcoded API key in config/services.rb:42
[H2] Private key tracked in certs/server.key
[M1] SQL injection risk in app/models/user.rb:87
[M2] Debug mode enabled in config/production.yml
```

### Step 3: Confirm Scope

Present findings and ask for confirmation:

```
Found 4 issues to remediate:

High Priority (2):
  [H1] Hardcoded API key - config/services.rb:42
  [H2] Private key tracked - certs/server.key

Medium Priority (2):
  [M1] SQL injection risk - app/models/user.rb:87
  [M2] Debug mode enabled - config/production.yml

Options:
  - Fix all (recommended)
  - Fix High only
  - Select individually
  - Cancel
```

### Step 4: Remediate Each Issue

Process each issue based on its type:

---

#### Hardcoded Secrets

**Detection:** API keys, passwords, tokens in code

**Remediation:**
1. Identify the secret type and variable name
2. Add to `.env.example` with placeholder:
   ```
   API_KEY=your_api_key_here
   ```
3. Update code to read from environment:
   ```ruby
   # Before
   api_key = "sk-abc123..."

   # After
   api_key = ENV.fetch('API_KEY')
   ```
4. Ensure `.env` is in `.gitignore`
5. **Warn user:** "Secret was exposed in git history. Rotate this credential immediately."

---

#### Tracked Sensitive Files

**Detection:** Private keys, credentials files, .env files in git

**Remediation:**
1. Add pattern to `.gitignore`:
   ```
   *.pem
   *.key
   .env
   ```
2. Remove from git tracking (keep file):
   ```bash
   git rm --cached <file>
   ```
3. **Ask user:** "Remove from git history entirely? (requires force push)"
   - If yes: Use `git filter-repo` or BFG
   - If no: Just untrack, warn about history

---

#### SQL Injection

**Detection:** String interpolation in queries

**Remediation:**
```ruby
# Before
User.where("name = '#{params[:name]}'")

# After
User.where(name: params[:name])
```

For complex queries:
```ruby
# Before
User.where("name LIKE '%#{params[:q]}%'")

# After
User.where("name LIKE ?", "%#{params[:q]}%")
```

---

#### Command Injection

**Detection:** User input in system/exec calls

**Remediation:**
```ruby
# Before
system("convert #{params[:file]} output.png")

# After
system("convert", params[:file], "output.png")
```

For shell commands, use array form or escape:
```ruby
# Using Shellwords
require 'shellwords'
system("convert #{Shellwords.escape(params[:file])} output.png")
```

---

#### XSS Vulnerabilities

**Detection:** `raw`, `html_safe` on user input, `innerHTML`

**Remediation:**
```ruby
# Before
<%= raw user_input %>

# After
<%= sanitize user_input %>
```

```javascript
// Before
element.innerHTML = userInput;

// After
element.textContent = userInput;
```

---

#### Insecure Configuration

**Detection:** Debug mode, permissive CORS, missing CSRF

**Remediation:**

Debug mode:
```yaml
# Before
debug: true

# After
debug: false  # or use environment variable
```

CORS wildcard:
```ruby
# Before
config.allowed_origins = '*'

# After
config.allowed_origins = ENV.fetch('ALLOWED_ORIGINS', 'https://myapp.com').split(',')
```

---

#### Weak Cryptography

**Detection:** MD5, SHA1 for passwords, weak random

**Remediation:**
```ruby
# Before
Digest::MD5.hexdigest(password)

# After
BCrypt::Password.create(password)
```

```javascript
// Before
Math.random().toString(36)

// After
crypto.randomUUID()
```

---

### Step 5: Update .gitignore

Consolidate all patterns that should be ignored:

```bash
# Check current .gitignore
cat .gitignore

# Add missing patterns
echo "
# Security - added by repo-security-clean
.env
.env.*
*.pem
*.key
*.p12
config/master.key
" >> .gitignore
```

### Step 6: Create Commit

Stage all changes and create a security fix commit:

```bash
git add -A
git commit -m "security: remediate issues from security scan

Fixed:
- [H1] Moved API key to environment variable
- [H2] Removed private key from tracking
- [M1] Fixed SQL injection in User model
- [M2] Disabled debug mode in production

Run 'git log --oneline -1' to see this commit.

⚠️  Action required:
- Rotate exposed credentials
- Review git history for sensitive data
"
```

**Do NOT auto-commit** - present the changes and ask:
```
Ready to commit these security fixes?

Changes:
  M  .gitignore
  M  config/services.rb
  M  app/models/user.rb
  D  certs/server.key (untracked, file preserved)

Options:
  - Commit now
  - Review changes first (git diff)
  - Cancel
```

### Step 7: Post-Remediation Report

Update the scan report or create a new one:

```markdown
# Security Clean Report

**Repository:** <repo-name>
**Date:** YYYY-MM-DD
**Action:** Automated remediation

## Actions Taken

### [H1] Hardcoded API Key - FIXED
- **File:** config/services.rb:42
- **Action:** Replaced with `ENV.fetch('API_KEY')`
- **Follow-up required:** Rotate the exposed key

### [H2] Private Key Tracked - FIXED
- **File:** certs/server.key
- **Action:** Added to .gitignore, removed from tracking
- **Follow-up required:** Consider removing from git history

## Manual Actions Required

1. **Rotate credentials:**
   - [ ] API key (was exposed in config/services.rb)
   - [ ] Any other secrets visible in git history

2. **Clean git history (optional but recommended):**
   ```bash
   # Install BFG Repo-Cleaner
   brew install bfg

   # Remove sensitive files from history
   bfg --delete-files server.key
   git reflog expire --expire=now --all
   git gc --prune=now --aggressive
   git push --force
   ```

3. **Enable secret scanning:**
   - GitHub: Settings → Security → Secret scanning
   - Add pre-commit hooks for local detection

## Summary

| Priority | Found | Fixed | Manual |
|----------|-------|-------|--------|
| High     | 2     | 2     | 0      |
| Medium   | 2     | 2     | 0      |
| Low      | 5     | 0     | 5      |
```

### Step 8: Final Summary

```
✓ Security clean complete

  Fixed: 4 issues
    [H1] Hardcoded API key → environment variable
    [H2] Private key → untracked
    [M1] SQL injection → parameterised query
    [M2] Debug mode → disabled

  Commit ready: Run 'git push' when ready

  ⚠️  Manual actions required:
    1. Rotate the exposed API key
    2. Consider cleaning git history
    3. Review low-priority items in report

  Report: security/YYYYMMDD-clean.md
```

## Safety Guardrails

1. **Always ask before:**
   - Modifying git history
   - Deleting files
   - Making commits

2. **Never automatically:**
   - Force push
   - Delete untracked files
   - Modify files outside the repo

3. **Preserve originals:**
   - Untrack sensitive files, don't delete them
   - User may need the actual credentials/keys

4. **Warn about:**
   - Exposed secrets in git history
   - Credentials that need rotation
   - Breaking changes (e.g., code now requires env vars)

## Limitations

- Cannot fix all vulnerability types automatically
- Some fixes may require manual review (complex SQL, business logic)
- Git history cleaning requires manual steps
- Does not rotate credentials (user must do this)

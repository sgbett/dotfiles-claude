---
name: repo-security-scan
description: Scans a repository for sensitive information and security vulnerabilities. Use when the user asks to "scan for security issues", "check for sensitive data", "repo security scan", "make sure this repo has no sensitive information", "security audit", "scan history for secrets", or "/repo-security-scan".
allowed-tools: Bash,Read,Write,Glob,Grep,AskUserQuestion
---

# Repository Security Scan

Scans the current repository for sensitive information, credentials, and security vulnerabilities. Produces a report and actionable remediation plan.

## Invocation

```
/repo-security-scan                  # Scan current files only (fast)
/repo-security-scan --history        # Include git history (slower)
"scan this repo for security issues"
"check for sensitive data"
"scan history for secrets"           # Triggers history scan
"deep security scan"                 # Triggers history scan
"security audit"
```

**History scanning** is opt-in because it's slower. Prompt the user if not specified:

```
Would you like to scan git history as well?
This finds secrets that were removed but are still in commit history.
(Slower - may take a few minutes on large repos)
```

## Workflow

### Step 1: Prepare Output Directory

```bash
mkdir -p security
```

Generate filename with today's date:
```
security/YYYYMMDD-scan.md
```

### Step 2: Gather Repository Context

```bash
# Get repo root
git rev-parse --show-toplevel

# List tracked files (excluding common binary/vendor paths)
git ls-files | grep -v -E '\.(png|jpg|gif|ico|woff|ttf|pdf)$'

# Check .gitignore exists
cat .gitignore 2>/dev/null
```

### Step 3: Scan for Sensitive Information

Search for patterns that indicate secrets or credentials:

#### High Priority - Hardcoded Secrets

| Pattern | Description |
|---------|-------------|
| `password\s*[:=]\s*['"][^'"]+['"]` | Hardcoded passwords |
| `api[_-]?key\s*[:=]\s*['"][^'"]+['"]` | API keys |
| `secret[_-]?key\s*[:=]\s*['"][^'"]+['"]` | Secret keys |
| `(aws_)?access[_-]?key[_-]?id\s*[:=]` | AWS access keys |
| `(aws_)?secret[_-]?access[_-]?key\s*[:=]` | AWS secret keys |
| `private[_-]?key` | Private keys |
| `-----BEGIN (RSA |DSA |EC |OPENSSH )?PRIVATE KEY-----` | PEM private keys |
| `Bearer\s+[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+` | JWT tokens |
| `ghp_[A-Za-z0-9]{36}` | GitHub personal access tokens |
| `sk-[A-Za-z0-9]{48}` | OpenAI API keys |
| `xox[baprs]-[A-Za-z0-9-]+` | Slack tokens |

#### Medium Priority - Potential Secrets

| Pattern | Description |
|---------|-------------|
| `[A-Za-z0-9]{32,}` in config files | Long alphanumeric strings (potential tokens) |
| `DATABASE_URL.*://.*:.*@` | Database connection strings with credentials |
| `mongodb(\+srv)?://[^/\s]+:[^/\s]+@` | MongoDB connection strings |
| `redis://:[^@]+@` | Redis connection strings |
| `smtp://[^:]+:[^@]+@` | SMTP credentials |

#### Low Priority - Review Recommended

| Pattern | Description |
|---------|-------------|
| `.env` files tracked in git | Environment files should be gitignored |
| `TODO.*secret\|password\|key` | TODOs mentioning secrets |
| `localhost` with port in configs | Development URLs in production configs |

### Step 4: Scan for Security Vulnerabilities

#### Code Patterns (by language)

**Ruby/Rails:**
| Pattern | Risk | Description |
|---------|------|-------------|
| `eval\(` | High | Arbitrary code execution |
| `send\(params` | High | Dynamic method calls with user input |
| `raw\s+params` | High | Unescaped user input in views |
| `html_safe` on user input | Medium | XSS vulnerability |
| `where\(".*#\{` | Medium | SQL injection risk |
| `render\s+inline:` | Medium | Template injection |
| `system\(.*params` | High | Command injection |
| `open\(.*params` | High | Path traversal |

**JavaScript/TypeScript:**
| Pattern | Risk | Description |
|---------|------|-------------|
| `eval\(` | High | Arbitrary code execution |
| `innerHTML\s*=` | Medium | XSS if user input |
| `dangerouslySetInnerHTML` | Medium | React XSS risk |
| `child_process.exec\(` with user input | High | Command injection |
| `new Function\(` | High | Dynamic code execution |

**Python:**
| Pattern | Risk | Description |
|---------|------|-------------|
| `eval\(` | High | Arbitrary code execution |
| `exec\(` | High | Arbitrary code execution |
| `pickle\.loads?\(` | High | Insecure deserialisation |
| `subprocess.*shell=True` | Medium | Shell injection risk |
| `__import__\(` with user input | High | Module injection |

**SQL:**
| Pattern | Risk | Description |
|---------|------|-------------|
| String concatenation in queries | High | SQL injection |
| `EXECUTE\s+@` | Medium | Dynamic SQL |

### Step 5: Check Configuration Security

| Check | Risk | Description |
|-------|------|-------------|
| Debug mode enabled in production configs | Medium | Information disclosure |
| CORS `*` wildcard | Medium | Overly permissive CORS |
| Missing CSRF protection | High | Cross-site request forgery |
| Weak SSL/TLS configuration | Medium | Man-in-the-middle risk |
| Default credentials in configs | High | Authentication bypass |

### Step 6: Check for Sensitive Files

Files that should typically be gitignored:

| File Pattern | Risk |
|--------------|------|
| `.env`, `.env.*` | High - Contains secrets |
| `*.pem`, `*.key` | High - Private keys |
| `*credentials*.json` | High - Cloud credentials |
| `*.p12`, `*.pfx` | High - Certificates with keys |
| `id_rsa`, `id_ed25519` | High - SSH private keys |
| `.docker/config.json` | Medium - Docker registry auth |
| `*.sqlite`, `*.db` | Medium - May contain sensitive data |
| `config/master.key` | High - Rails credentials key |
| `config/credentials.yml.enc` without master.key | OK - Encrypted |

### Step 7: Scan Git History (if requested)

If user requested history scanning (`--history` or confirmed prompt), scan commit history for secrets.

#### Option A: Use gitleaks (preferred)

Check if gitleaks is installed:
```bash
gitleaks version 2>/dev/null
```

If installed, run comprehensive scan:
```bash
# Scan all commits
gitleaks detect --source . --log-opts="--all" --report-format json --report-path /tmp/gitleaks-report.json

# Parse results
cat /tmp/gitleaks-report.json
```

Gitleaks output includes:
- Secret type (API key, password, etc.)
- File path
- Commit hash where introduced
- Line number
- Whether still present or removed

#### Option B: Use trufflehog (alternative)

```bash
trufflehog version 2>/dev/null
```

If installed:
```bash
trufflehog git file://. --only-verified --json
```

#### Option C: Native git search (fallback)

If no dedicated tools installed, use git directly (slower, less comprehensive):

```bash
# Search for high-priority patterns in all commit diffs
git log -p --all -S 'password' --pickaxe-regex -S '["\x27]sk-[A-Za-z0-9]{20,}["\x27]' 2>/dev/null | head -500

# Search for specific patterns
git log -p --all | grep -E "(api[_-]?key|secret[_-]?key|password)\s*[:=]\s*['\"][^'\"]{8,}['\"]" | head -100

# Find commits that touched sensitive files
git log --all --full-history --source -- "*.pem" "*.key" ".env" "*credentials*" "*.p12"

# Check for secrets in deleted files
git log --diff-filter=D --summary --all | grep -E "\.(pem|key|env)$"
```

#### Categorise History Findings

Label each finding by location:

| Location | Meaning | Risk |
|----------|---------|------|
| **Current** | In current files | High - actively exposed |
| **History** | Removed from files but in git history | High - still accessible |
| **History-only** | Never in current files (deleted file) | Medium - requires history access |

Example output:
```
[H3] AWS Secret Key (HISTORY)
- **Commit:** abc1234 (2024-03-15)
- **File:** config/aws.yml (since removed)
- **Status:** Removed from current files, but remains in git history
- **Risk:** Anyone with repo access can retrieve this from history
- **Recommendation:** Use /repo-security-purge to remove from history, rotate credential
```

### Step 8: Generate Report

Write findings to `security/YYYYMMDD-scan.md`:

```markdown
# Security Scan Report

**Repository:** <repo-name>
**Date:** YYYY-MM-DD
**Scanned by:** Claude Code
**History scanned:** Yes/No

## Summary

| Priority | Current | History | Total |
|----------|---------|---------|-------|
| High     | X       | X       | X     |
| Medium   | X       | X       | X     |
| Low      | X       | X       | X     |

## Current File Findings

### High Priority

#### [H1] Hardcoded API Key
- **Location:** Current
- **File:** `config/services.rb:42`
- **Pattern:** `api_key = "sk-..."`
- **Risk:** API key exposed in version control
- **Recommendation:** Move to environment variable or encrypted credentials

### Medium Priority

#### [M1] Potential SQL Injection
- **Location:** Current
- **File:** `app/models/user.rb:87`
- **Pattern:** `where("name = '#{params[:name]}'")`
- **Risk:** User input interpolated into SQL query
- **Recommendation:** Use parameterised queries: `where(name: params[:name])`

## Git History Findings

### High Priority

#### [H2] AWS Secret Access Key (HISTORY)
- **Location:** History (removed from current files)
- **Commit:** `abc1234` (2024-03-15, "Add AWS config")
- **File:** `config/aws.yml` (deleted in `def5678`)
- **Risk:** Credential accessible to anyone with repo access via git history
- **Recommendation:**
  1. Rotate this AWS credential immediately
  2. Use `/repo-security-purge` to remove from history

#### [H3] Private Key File (HISTORY)
- **Location:** History
- **Commit:** `ghi9012` (2024-01-10)
- **File:** `certs/server.key` (still tracked)
- **Risk:** Private key in version control history
- **Recommendation:**
  1. Revoke and regenerate certificate
  2. Use `/repo-security-purge` to remove from history

### Low Priority

#### [L1] Development URL in Config
- **Location:** Current
- **File:** `config/settings.yml:12`
- **Pattern:** `api_url: http://localhost:3000`
- **Risk:** Development configuration may be deployed
- **Recommendation:** Use environment-specific configuration

## Scan Details

| Metric | Value |
|--------|-------|
| Current files scanned | X |
| Commits scanned | X (if history enabled) |
| File types | .rb, .js, .py, .yml, .json, ... |
| Scan tool | gitleaks / trufflehog / native git |

## Scan Limitations

- This scan uses pattern matching and may produce false positives
- Manual review recommended for all findings
- Does not scan binary files or dependencies
- History scan may miss secrets in squashed/rebased commits
```

### Step 9: Create Remediation Plan

For issues Medium priority and above, create an actionable plan:

```markdown
## Remediation Plan

### Immediate Actions (High Priority)

1. **[H1] Remove hardcoded API key** (Current)
   - [ ] Add `API_KEY` to `.env` (gitignored)
   - [ ] Update `config/services.rb` to read from `ENV['API_KEY']`
   - [ ] Rotate the exposed key in the provider dashboard

2. **[H2] AWS credential in history** (History)
   - [ ] Rotate AWS credential immediately
   - [ ] Run `/repo-security-purge` to remove from git history
   - [ ] Verify removal with `/repo-security-scan --history`

### Short-term Actions (Medium Priority)

3. **[M1] Fix SQL injection vulnerability**
   - [ ] Refactor to use parameterised queries
   - [ ] Add test case for SQL injection attempt
   - [ ] Review similar patterns in codebase

### Recommended Improvements

- [ ] Add `gitleaks` or `trufflehog` to CI pipeline
- [ ] Enable GitHub secret scanning
- [ ] Review and update `.gitignore`
- [ ] Set up pre-commit hooks to prevent secret commits
```

### Step 10: Report Results

```
✓ Security scan complete

  Report: security/YYYYMMDD-scan.md

  Current files:
    High:   1 issue
    Medium: 2 issues
    Low:    3 issues

  Git history:          (if scanned)
    High:   2 issues
    Medium: 0 issues

  Total: 8 issues (3 require immediate action)

  Remediation plan included for 5 actionable items.

  Next steps:
    1. Review the full report
    2. Address High priority issues immediately
    3. Run /repo-security-clean to fix current file issues
    4. Run /repo-security-purge to remove secrets from history
```

## Excluding False Positives

If the repo has a `security/.scanignore` file, respect it:

```
# Patterns to ignore (one per line)
# Comments start with #

test/fixtures/fake_credentials.yml
docs/examples/
*.test.js
```

## Notes

- This scan uses pattern matching and may produce false positives
- Always manually verify findings before taking action
- History scanning uses gitleaks/trufflehog if installed, falls back to native git
- Secrets in history are just as dangerous as current secrets — assume compromised
- After fixing, use `/repo-security-clean` for current files, `/repo-security-purge` for history
- Consider adding gitleaks to CI pipeline to prevent future secret commits

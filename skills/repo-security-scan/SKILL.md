---
name: repo-security-scan
description: Scans a repository for sensitive information and security vulnerabilities. Use when the user asks to "scan for security issues", "check for sensitive data", "repo security scan", "make sure this repo has no sensitive information", "security audit", or "/repo-security-scan".
allowed-tools: Bash,Read,Write,Glob,Grep
---

# Repository Security Scan

Scans the current repository for sensitive information, credentials, and security vulnerabilities. Produces a report and actionable remediation plan.

## Invocation

```
/repo-security-scan
"scan this repo for security issues"
"check for sensitive data"
"make sure there's no sensitive information"
"security audit"
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

### Step 7: Generate Report

Write findings to `security/YYYYMMDD-scan.md`:

```markdown
# Security Scan Report

**Repository:** <repo-name>
**Date:** YYYY-MM-DD
**Scanned by:** Claude Code

## Summary

| Priority | Count |
|----------|-------|
| High     | X     |
| Medium   | X     |
| Low      | X     |

## Findings

### High Priority

#### [H1] Hardcoded API Key
- **File:** `config/services.rb:42`
- **Pattern:** `api_key = "sk-..."`
- **Risk:** API key exposed in version control
- **Recommendation:** Move to environment variable or encrypted credentials

### Medium Priority

#### [M1] Potential SQL Injection
- **File:** `app/models/user.rb:87`
- **Pattern:** `where("name = '#{params[:name]}'")`
- **Risk:** User input interpolated into SQL query
- **Recommendation:** Use parameterised queries: `where(name: params[:name])`

### Low Priority

#### [L1] Development URL in Config
- **File:** `config/settings.yml:12`
- **Pattern:** `api_url: http://localhost:3000`
- **Risk:** Development configuration may be deployed
- **Recommendation:** Use environment-specific configuration

## Files Reviewed

- Total files scanned: X
- File types: .rb, .js, .py, .yml, .json, ...

## Scan Limitations

- This scan uses pattern matching and may produce false positives
- Manual review recommended for all findings
- Does not scan binary files or dependencies
```

### Step 8: Create Remediation Plan

For issues Medium priority and above, create an actionable plan:

```markdown
## Remediation Plan

### Immediate Actions (High Priority)

1. **[H1] Remove hardcoded API key**
   - [ ] Add `API_KEY` to `.env` (gitignored)
   - [ ] Update `config/services.rb` to read from `ENV['API_KEY']`
   - [ ] Rotate the exposed key in the provider dashboard
   - [ ] Audit git history for other exposed secrets

### Short-term Actions (Medium Priority)

2. **[M1] Fix SQL injection vulnerability**
   - [ ] Refactor to use parameterised queries
   - [ ] Add test case for SQL injection attempt
   - [ ] Review similar patterns in codebase

### Recommended Improvements

- [ ] Add `gitleaks` or `trufflehog` to CI pipeline
- [ ] Enable GitHub secret scanning
- [ ] Review and update `.gitignore`
```

### Step 9: Report Results

```
✓ Security scan complete

  Report: security/YYYYMMDD-scan.md

  Summary:
    High:   2 issues (action required)
    Medium: 3 issues (action required)
    Low:    5 issues (review recommended)

  Remediation plan included for 5 actionable items.

  Next steps:
    1. Review the full report
    2. Address High priority issues immediately
    3. Schedule Medium priority fixes
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
- Consider running dedicated tools (gitleaks, trufflehog, semgrep) for comprehensive coverage
- Rotate any secrets found in git history, not just current files

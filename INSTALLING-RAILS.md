# Installing Rails - Personal Setup Guide

This document provides personalised instructions for creating a new Rails project from scratch.

## Prerequisites

- macOS
- rvm (Ruby Version Manager)
- GitHub CLI (`gh`)

## Steps

### 1. Create project folder

```bash
mkdir -p /opt/ruby/<project_name>
cd /opt/ruby/<project_name>
```

### 2. Install latest stable Ruby via rvm

Check available versions:
```bash
rvm list known | grep -E "^\[ruby-\]"
```

Install (e.g., Ruby 3.4.2):
```bash
rvm install 3.4.2
```

### 3. Set Ruby version for project

```bash
rvm use 3.4.2
echo "ruby-3.4.2" > .ruby-version
```

### 4. Install Rails

Check latest version:
```bash
gem search ^rails$ --remote
```

Install (e.g., Rails 8.1.1):
```bash
gem install rails -v 8.1.1
```

### 5. Generate Rails project

Using `--skip-test` (RSpec) and `-d postgresql` (not SQLite):
```bash
rails new . --skip-test -d postgresql
```

### 6. Install Importmap

Rails 8 includes `importmap-rails` in the Gemfile but doesn't run the installer. The generated CI workflow expects `bin/importmap audit` to work:

```bash
bin/rails importmap:install
```

This creates:
- `bin/importmap` (binstub)
- `config/importmap.rb` (configuration)
- `app/javascript/application.js` (JS entrypoint)
- `vendor/javascript/` (for vendored JS)
- Adds `javascript_importmap_tags` to the layout

### 7. Add RSpec

Add to `Gemfile` in the `:development, :test` group:
```ruby
gem 'rspec-rails'
```

Then:
```bash
bundle install
rails generate rspec:install
```

### 8. Rename branch to master

`rails new` initialises git with `main`. Rename to `master`:
```bash
git branch -m main master
```

### 9. Fix CI workflow

Rails defaults to `main`. Check and fix any references:
```bash
grep -r "main" .github/
```

In `.github/workflows/ci.yml`, change:
```yaml
branches: [ main ]
```
to:
```yaml
branches: [ master ]
```

Also update GitHub Actions to latest versions (Rails generates older ones):
- `actions/checkout@v5` → `actions/checkout@v6`
- `actions/cache@v4` → `actions/cache@v5`

Also add `.claude/settings.local.json` to `.gitignore` (per-machine overrides):
```bash
echo -e "\n# Ignore Claude Code local settings.\n/.claude/settings.local.json" >> .gitignore
```

Note: The rest of `.claude/` (settings.json, commands/, agents/) is designed for version control.

### 10. Update gems

```bash
bundle update
```

### 11. Verify setup

```bash
bin/rspec              # should pass (no tests yet)
bin/rails server       # should start on localhost:3000
```

### 12. Create GitHub repo and push

```bash
git add .
git commit -m "chore: initial Rails 8.1.1 project with RSpec"
gh repo create <username>/<project_name> --public --source=. --push
```

---

## PostgreSQL Setup

All Rails projects share a single PostgreSQL instance running in Docker (container: `postgres-db-1`).

### Database User

A shared `rails` user with `CREATEDB` privileges is used for all Rails development databases.

Password is stored in `~/.pgpass` (format: `*:*:*:rails:<password>`).

### database.yml Configuration

When using `rails new . -d postgresql`, it generates a default config. Update it to use the shared `rails` user:

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  host: <%= ENV.fetch("DATABASE_HOST") { "localhost" } %>
  username: <%= ENV.fetch("DATABASE_USERNAME") { "rails" } %>

development:
  <<: *default
  database: <app_name>_development

test:
  <<: *default
  database: <app_name>_test

production:
  primary:
    <<: *default
    database: <app_name>_production
    password: <%= ENV["DATABASE_PASSWORD"] %>
```

**Note:** No password in development/test sections - `~/.pgpass` handles authentication automatically.

### Creating Databases

```bash
bin/rails db:create
```

---

## Troubleshooting

### Puma fails to compile with OpenSSL errors

If you see errors like:
```
mini_ssl.c:707:10: error: call to undeclared function 'SSL_get1_peer_certificate'
```

This happens when Homebrew has both `openssl@1.1` and `openssl@3` installed, and puma tries to compile against `openssl@1.1` which lacks OpenSSL 3.0 functions.

**Solution:**
```bash
bundle config set build.puma --with-openssl-dir=$(brew --prefix openssl@3)
bundle install
```

### `bin/rspec` not found

The RSpec binstub isn't generated automatically. Create it with:
```bash
bundle binstubs rspec-core
```

---

## Quick Reference

| Item | Preference |
|------|------------|
| Ruby manager | rvm |
| Project location | `/opt/ruby/<project_name>` |
| Default branch | `master` |
| Testing framework | RSpec |
| Database | PostgreSQL |
| Rails install | `--skip-test -d postgresql` |

---

*Last updated: January 2026*
*Rails version: 8.1.1*
*Ruby version: 3.4.2*

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

### 6. Add RSpec

Add to `Gemfile` in the `:development, :test` group:
```ruby
gem 'rspec-rails'
```

Then:
```bash
bundle install
rails generate rspec:install
```

### 7. Rename branch to master

`rails new` initialises git with `main`. Rename to `master`:
```bash
git branch -m main master
```

### 8. Fix CI workflow

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

For optional project setup (plans folder, rules), see `~/.claude/playbooks/`.

### 9. Update gems

```bash
bundle update
```

### 10. Add Docker support

Create `Dockerfile`:

```dockerfile
# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.4.2
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl libjemalloc2 libvips postgresql-client && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV BUNDLE_PATH="/usr/local/bundle" \
    LD_PRELOAD=/usr/local/lib/libjemalloc.so

FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock vendor ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile -j 1 --gemfile

COPY . .

RUN bundle exec bootsnap precompile -j 1 app/ lib/
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

FROM base

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
```

> **Note**: This Dockerfile is for local development with bind mounts. For production deployments (e.g., ECS Fargate), you'd use a different configuration with `RAILS_ENV=production`, `BUNDLE_DEPLOYMENT=1`, and appropriate security hardening.

Create `docker-compose.yml`:

```yaml
services:
  app:
    build: .
    ports:
      - "3000:80"
    volumes:
      - .:/rails                         # Bind mount for live code editing
      - bundle_cache:/usr/local/bundle   # Persist gems across restarts
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      - RAILS_ENV=development
      - DATABASE_HOST=postgres
      - DATABASE_PORT=5432
      - DATABASE_USERNAME=rails
      - DATABASE_PASSWORD=rails
      - RAILS_MASTER_KEY=${RAILS_MASTER_KEY}

  worker:
    build: .
    command: bin/jobs
    volumes:
      - .:/rails
      - bundle_cache:/usr/local/bundle
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      - RAILS_ENV=development
      - DATABASE_HOST=postgres
      - DATABASE_PORT=5432
      - DATABASE_USERNAME=rails
      - DATABASE_PASSWORD=rails
      - RAILS_MASTER_KEY=${RAILS_MASTER_KEY}

  postgres:
    image: postgres:17
    ports:
      - "55432:5432"                     # Expose on 55432 to avoid conflicts
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_USER: rails
      POSTGRES_PASSWORD: rails
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U rails"]
      interval: 2s
      timeout: 5s
      retries: 10

volumes:
  postgres_data:
  bundle_cache:
```

> **Security Note**: The `rails`/`rails` credentials above are for local development only. Never commit real credentials to version control.

Key features:
- **Bind mount** (`.:/rails`) - Edit code on host, changes visible immediately in container
- **bundle_cache volume** - Gems persist across container restarts
- **DATABASE_PORT=5432** - Inside Docker network, postgres listens on 5432 (not the host-exposed 55432)
- **RAILS_ENV=development** - Enables auto-reload and development features

Create `.dockerignore`:

```
.git
.gitignore
log/*
tmp/*
storage/*
.env*
*.md
.rspec
spec/
.claude/
```

Update `config/database.yml` default section to include password and port:

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  host: <%= ENV.fetch("DATABASE_HOST") { "localhost" } %>
  port: <%= ENV.fetch("DATABASE_PORT") { 55432 } %>
  username: <%= ENV.fetch("DATABASE_USERNAME") { "rails" } %>
  password: <%= ENV.fetch("DATABASE_PASSWORD", nil) %>
```

The port defaults to 55432 (host-exposed port for local dev without Docker), but docker-compose sets `DATABASE_PORT=5432` for container-to-container communication.

Create `.env` file (add to `.gitignore`):

```
RAILS_MASTER_KEY=<value from config/master.key>
```

> **Security Warning**: The master key decrypts all Rails credentials (`config/credentials.yml.enc`). Never commit `config/master.key` or share the key value. For production, use your deployment platform's secrets management rather than `.env` files.

### 11. Verify setup

**Local development:**
```bash
bin/rspec              # should pass (no tests yet)
bin/rails server       # should start on localhost:3000
```

**Docker:**
```bash
docker compose up -d   # starts app, worker, postgres
```

App available at http://localhost:3000

---

### 12. Create GitHub repo and push

```bash
git add .
git commit -m "chore: initial Rails 8.1.1 project with RSpec"
gh repo create <username>/<project_name> --public --source=. --push
```

---

## PostgreSQL Setup

### Docker (Recommended)

Each project has its own PostgreSQL container via `docker-compose.yml`. Database is created automatically on first run.

To access the database directly:
```bash
docker compose exec postgres psql -U rails -d <app_name>_production
```

### Local Development

For local development (without Docker), a shared PostgreSQL instance runs in Docker (container: `postgres-db-1`).

A shared `rails` user with `CREATEDB` privileges is used. Password stored in `~/.pgpass` (format: `*:*:*:rails:<password>`).

### database.yml Configuration

When using `rails new . -d postgresql`, update the generated config:

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  host: <%= ENV.fetch("DATABASE_HOST") { "localhost" } %>
  port: <%= ENV.fetch("DATABASE_PORT") { 55432 } %>
  username: <%= ENV.fetch("DATABASE_USERNAME") { "rails" } %>
  password: <%= ENV.fetch("DATABASE_PASSWORD", nil) %>

development:
  <<: *default
  database: <app_name>_development

test:
  <<: *default
  database: <app_name>_test
```

**Note:** Port defaults to 55432 (host-exposed). Docker sets `DATABASE_PORT=5432` for container networking. Password uses `nil` default so `~/.pgpass` works for local dev without Docker.

### Creating Databases

**Local:**
```bash
bin/rails db:create
```

**Docker:**
```bash
docker compose exec app bin/rails db:create db:migrate
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

### `.pgpass` not working

PostgreSQL ignores `.pgpass` if permissions are too open. Must be `600`:
```bash
chmod 600 ~/.pgpass
```

### `.pgpass` ignored despite correct permissions

Check for a `PGPASSWORD` environment variable — it takes precedence over `.pgpass`:
```bash
env | grep PGPASSWORD
unset PGPASSWORD
```

### Database connection fails for new app

The shared PostgreSQL `pg_hba.conf` may need a rule for the `rails` user. Add:
```
host    all    rails    0.0.0.0/0    scram-sha-256
```

Then reload:
```bash
docker exec postgres-db-1 psql -U postgres -c "SELECT pg_reload_conf()"
```

---

## Quick Reference

| Item | Preference |
|------|------------|
| Ruby manager | rvm (local dev) |
| Project location | `/opt/ruby/<project_name>` |
| Default branch | `master` |
| Testing framework | RSpec |
| Database | PostgreSQL 17 (Docker) |
| Rails install | `--skip-test -d postgresql` |
| Docker setup | Bind mounts for local dev |

---

*Last updated: January 2026 (simplified Docker setup for local dev with bind mounts)*
*Rails version: 8.1.1*
*Ruby version: 3.4.2*

---
name: new-project-rails
description: Creates a new Rails project with personal preferences (RSpec, PostgreSQL, Docker, master branch). Use when the user asks to "create a new Rails project", "start a new Rails app", "new-project-rails", or "/new-project-rails <name>".
allowed-tools: Bash,Read,Write,Edit,AskUserQuestion
---

# New Rails Project

Creates a new Rails project following personal conventions from `~/.claude/NEW-PROJECT-RAILS.md`.

## Invocation

```
/new-project-rails                    # Interactive - prompt for project name
/new-project-rails <project-name>     # Create project with specified name
```

## Project Conventions

| Setting | Value |
|---------|-------|
| Location | `/opt/ruby/<project-name>` |
| Ruby manager | rvm |
| Default branch | `master` (not main) |
| Testing | RSpec (not Minitest) |
| Database | PostgreSQL (not SQLite) |
| Docker | Yes - with bind mounts for local dev |

## Workflow

### Step 1: Gather Input

**Required:** Project name

**Confidence thresholds:**
- Project name provided → proceed (90%)
- No name provided → prompt user

**Validation:**
- Name should be lowercase, alphanumeric with underscores/hyphens
- Check `/opt/ruby/<name>` doesn't already exist

### Step 2: Determine Versions

Check latest stable versions:

```bash
# Latest Ruby
rvm list known | grep -E "^\[ruby-\]" | tail -5

# Latest Rails
gem search ^rails$ --remote | head -1
```

**Confidence thresholds:**
- Clear latest stable version → use it (85%)
- Multiple candidates or unclear → suggest and confirm

### Step 3: Create Project Structure

```bash
# Create and enter directory
mkdir -p /opt/ruby/<project-name>
cd /opt/ruby/<project-name>

# Set Ruby version
rvm install <ruby-version>  # if not already installed
rvm use <ruby-version>
echo "ruby-<version>" > .ruby-version

# Install Rails
gem install rails -v <rails-version>

# Generate project
rails new . --skip-test -d postgresql
```

### Step 4: Configure Testing

```bash
# Add RSpec to Gemfile (in :development, :test group)
# The gem line should be added after the group declaration

bundle install
rails generate rspec:install
bundle binstubs rspec-core
```

Add to Gemfile in `:development, :test` group:
```ruby
gem 'rspec-rails'
```

### Step 5: Fix Git Branch

```bash
# Rename main to master
git branch -m main master

# Fix CI workflow references
sed -i '' 's/branches: \[ main \]/branches: [ master ]/' .github/workflows/ci.yml
```

### Step 6: Update CI Workflow

In `.github/workflows/ci.yml`:
- Update `actions/checkout` to latest (v6)
- Update `actions/cache` to latest (v5)
- Ensure branch references use `master`

### Step 7: Configure .gitignore

Add to `.gitignore`:
```
# Ignore Claude Code local settings
/.claude/settings.local.json
```

### Step 8: Create Docker Files

Read templates from `~/.claude/NEW-PROJECT-RAILS.md` and create:

1. **Dockerfile** - Multi-stage build with bind mount support
2. **docker-compose.yml** - App, worker, postgres services
3. **.dockerignore** - Exclude dev/test files

Substitute `<ruby-version>` in Dockerfile.

### Step 9: Configure Database

Update `config/database.yml` default section:

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

### Step 10: Create .env Template

Create `.env` with placeholder:
```
RAILS_MASTER_KEY=<paste from config/master.key>
```

Add `.env` to `.gitignore` if not already present.

### Step 11: Configure Background Jobs (if using worker)

Check if SolidQueue is present. If so, add to `config/environments/development.rb`:

```ruby
# Use SolidQueue for background jobs (same as production)
config.active_job.queue_adapter = :solid_queue
```

### Step 12: Update Gems

```bash
bundle update
```

### Step 13: Verify Setup

```bash
# Run specs (should pass - no tests yet)
bin/rspec

# Verify Rails starts
bin/rails server &
sleep 3
curl -s http://localhost:3000 > /dev/null && echo "Rails running OK"
kill %1
```

### Step 14: Report Success

```
✓ Rails project created successfully

  Project: <project-name>
  Path:    /opt/ruby/<project-name>
  Ruby:    <ruby-version>
  Rails:   <rails-version>

  Next steps:
    cd /opt/ruby/<project-name>

    # Local development:
    bin/rails db:create
    bin/rails server

    # Docker development:
    # First, copy master key to .env:
    cat config/master.key  # copy this value
    # Edit .env and paste as RAILS_MASTER_KEY value
    docker compose up -d

    # Create GitHub repo:
    git add .
    git commit -m "chore: initial Rails <rails-version> project with RSpec"
    gh repo create <username>/<project-name> --public --source=. --push

  Troubleshooting: ~/.claude/NEW-PROJECT-RAILS.md
```

## Error Handling

| Error | Resolution |
|-------|------------|
| Directory exists | Warn and ask to proceed or choose different name |
| Ruby version not found | Offer to install via rvm |
| Bundle install fails | Check for OpenSSL issues (see NEW-PROJECT-RAILS.md troubleshooting) |
| Port 3000 in use | Note in output, suggest killing process |

## Templates Reference

All file templates are defined in `~/.claude/NEW-PROJECT-RAILS.md`. Read that file to get the exact content for:
- Dockerfile (Step 10)
- docker-compose.yml (Step 10)
- .dockerignore (Step 10)
- database.yml default section (Step 10)

This ensures the skill stays in sync with the guide.

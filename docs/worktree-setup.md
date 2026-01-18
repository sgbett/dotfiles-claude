# Git Worktree Setup Guide

## Overview

Git worktrees allow you to have multiple branches checked out simultaneously in separate directories. This is particularly useful for running multiple Claude Code sessions on the same project without conflicts.

**Use cases:**
- Running parallel Claude sessions on different features
- Working on a feature branch while keeping master available for hotfixes
- Running tests on one branch while developing on another
- Comparing behaviour between branches side-by-side

## Quick Start

### Create a Worktree

```bash
# From main repository
cd /path/to/project

# Create worktree for an existing branch
git worktree add /path/to/project-<suffix> <branch-name>

# Create worktree with a new branch
git worktree add -b <new-branch-name> /path/to/project-<suffix>
```

**Examples:**
```bash
# Feature work
git worktree add /opt/ruby/myapp-bootstrap feature/#1252_bootstrap-helper-abstraction

# New feature branch
git worktree add -b feature/#1300_new-feature /opt/ruby/myapp-newfeature
```

### Set Up the Worktree

```bash
cd /path/to/project-<suffix>

# Install dependencies (Ruby example)
bundle install

# Verify setup
bundle exec rspec spec/models/user_spec.rb --dry-run
```

### Worktree Management

```bash
# List all worktrees
git worktree list

# Remove a worktree (when done)
git worktree remove /path/to/project-<suffix>

# Prune stale worktree references
git worktree prune
```

## Naming Conventions

| Work Type | Path Suffix | Example |
|-----------|-------------|---------|
| Feature work | `-<feature-keyword>` | `myapp-bootstrap` |
| Framework upgrade | `-<framework>` | `myapp-rails5` |
| Experiment | `-experiment` | `myapp-experiment` |

## Database Strategy

### Same Schema (Default)

For most feature work (refactoring, new features, bug fixes), **share the same database**:

```bash
# Both worktrees use the same database
# myapp_development / myapp_test
```

This works because:
- No schema changes between branches
- Same migrations on both
- Simpler setup

### Separate Databases (When Needed)

Use separate databases when branches have **incompatible schemas** (e.g., Rails upgrades):

Create `config/database.yml.local` in the worktree (gitignored):

```yaml
development:
  <<: *default
  database: myapp_<suffix>_development

test:
  <<: *default
  database: myapp_<suffix>_test<%= ENV['TEST_ENV_NUMBER'] %>
```

Then set up the database:

```bash
bundle exec rake db:create db:migrate

# Optionally clone data from main database
pg_dump myapp_development | psql myapp_<suffix>_development
```

## Service Isolation

### Shared Services (Default)

For most worktrees, **share the same services** (PostgreSQL, Redis, Elasticsearch):

```bash
# Start services from main repo (either location works)
cd /path/to/project
docker compose up -d
```

Both worktrees connect to the same services on default ports.

### Separate Services (When Needed)

For major upgrades requiring different service versions, use port isolation:
- Main services on default ports
- Worktree services on offset ports (e.g., +100)

## Syncing Changes

### Merge Master into Feature Branch

Use **merge** (not rebase) for long-running branches:

```bash
cd /path/to/project-<suffix>
git fetch origin
git merge origin/master
```

**Why merge over rebase?**
- Preserves commit history
- No force-push required
- Easier conflict resolution
- Allows collaborative work

### Handling Gemfile.lock Conflicts

```bash
# Always regenerate, don't manually merge
git checkout --theirs Gemfile.lock
bundle install
git add Gemfile.lock
git commit
```

## Workflow with Multiple Claude Sessions

### Parallel Development

```bash
# Terminal 1: Claude session on feature A
cd /opt/ruby/myapp-feature-a
claude

# Terminal 2: Claude session on feature B
cd /opt/ruby/myapp-feature-b
claude

# Terminal 3: Main repo for quick fixes
cd /opt/ruby/myapp
claude
```

Each Claude session works independently without branch conflicts.

### Running Tests in Parallel

```bash
# Terminal 1: Full test suite on feature branch
cd /opt/ruby/myapp-feature
bundle exec rspec

# Terminal 2: Specific tests on master for comparison
cd /opt/ruby/myapp
bundle exec rspec spec/helpers/bootstrap_helper_spec.rb
```

## Cleanup

When feature work is complete and merged:

```bash
# From main repository
cd /path/to/project

# Remove the worktree
git worktree remove /path/to/project-<suffix>

# If worktree directory was manually deleted, prune the reference
git worktree prune

# Delete the branch if no longer needed
git branch -d feature/#1252_bootstrap-helper-abstraction
```

## Troubleshooting

### "fatal: '<branch>' is already checked out"

A branch can only be checked out in one worktree at a time:

```bash
# Find where it's checked out
git worktree list

# Either remove that worktree or use a different branch
```

### Worktree shows as "prunable"

The directory was deleted without using `git worktree remove`:

```bash
git worktree prune
```

### Bundle issues between worktrees

Each worktree has its own `vendor/bundle` if using `--path`:

```bash
cd /path/to/project-<suffix>
bundle install --path vendor/bundle
```

Or use a shared gem path (default behaviour).

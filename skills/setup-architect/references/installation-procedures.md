# Installation Procedures - Detailed Guide

This document provides detailed step-by-step procedures for installing the AI Software Architect framework in a project.

## Table of Contents

1. [Prerequisites Verification](#prerequisites-verification)
2. [Framework Installation](#framework-installation)
3. [Agent Documentation Setup](#agent-documentation-setup)
4. [Cleanup Procedures](#cleanup-procedures)
5. [Troubleshooting](#troubleshooting)

---

## Prerequisites Verification

Before installing, verify the environment is ready.

### Check Framework is Cloned

The framework must be cloned into `.architecture/.architecture/`:

```bash
if [ ! -d ".architecture/.architecture" ]; then
  echo "❌ Framework not found. Please clone first:"
  echo "   git clone https://github.com/codenamev/ai-software-architect .architecture/.architecture"
  exit 1
fi

echo "✅ Framework found at .architecture/.architecture"
```

### Confirm Project Root

Verify we're in the project root directory:

```bash
# Look for common project markers
if [ -f "package.json" ] || [ -f "Gemfile" ] || [ -f "requirements.txt" ] || [ -f "go.mod" ] || [ -f "Cargo.toml" ]; then
  echo "✅ In project root"
else
  echo "⚠️  No project markers found. Are you in the project root?"
  # Continue but warn user
fi
```

---

## Framework Installation

### Step 1: Copy Framework Files

Copy **only the required files** from the cloned framework. The framework contains its own ADRs, reviews, and internal documentation that should NOT be copied to user projects.

```bash
# Create target directory
mkdir -p .architecture

# Copy only required configuration files
cp .architecture/.architecture/.architecture/config.yml .architecture/
cp .architecture/.architecture/.architecture/members.yml .architecture/
cp .architecture/.architecture/.architecture/principles.md .architecture/

# Copy templates directory
cp -r .architecture/.architecture/.architecture/templates .architecture/

# Copy deferrals template (from templates, not the framework's populated version)
cp .architecture/.architecture/.architecture/templates/deferrals.md .architecture/deferrals.md

# Copy agent documentation
cp -r .architecture/.architecture/.architecture/agent_docs .architecture/

echo "✅ Framework files copied"
```

**DO NOT copy these** (framework internals/examples):
- `decisions/adrs/ADR-*` - framework's own architectural decisions
- `reviews/*` - framework's example reviews
- `deferrals.md` - framework's 50KB deferral log
- `documentation-*.md` - framework internal documentation
- `instruction-counting-methodology.md` - framework internal
- `quarterly-review-process.md` - framework internal
- `recalibration_process.md` - framework internal
- `comparisons/*` - framework comparison documents
- `recalibration/*` - framework recalibration documents

**DO NOT copy from clone root**:
- `AGENTS.md` - framework documentation (not project-specific)
- `.coding-assistants/` - multi-assistant setup docs (not needed once installed)

### Step 2: Remove Clone Directory

Clean up the temporary clone directory:

```bash
# Remove the clone directory (no longer needed)
rm -rf .architecture/.architecture

if [ ! -d ".architecture/.architecture" ]; then
  echo "✅ Clone directory removed"
fi
```

### Step 3: Create Directory Structure

Create empty directories for project-specific content:

```bash
# Create architecture directories (for project content)
mkdir -p .architecture/decisions/adrs
mkdir -p .architecture/reviews
mkdir -p .architecture/recalibration
mkdir -p .architecture/comparisons

echo "✅ Directory structure created"
```

**Note**: Do NOT create `.coding-assistants/` - this is framework setup documentation not needed in user projects.

### Step 4: Initialize Configuration

Copy the default configuration file:

```bash
# Copy config template if exists
if [ -f ".architecture/templates/config.yml" ]; then
  cp .architecture/templates/config.yml .architecture/config.yml
  echo "✅ Configuration initialized"
else
  echo "⚠️  No config template found"
fi
```

**Verify installation**:
```bash
# Check key directories exist
test -d .architecture/decisions/adrs && \
test -d .architecture/reviews && \
test -f .architecture/members.yml && \
test -f .architecture/principles.md && \
echo "✅ Installation verified" || echo "❌ Installation incomplete"
```

---

## Agent Documentation Setup

Following ADR-006 (Progressive Disclosure), create agent-specific documentation.

### Copy Existing Agent Docs (If Available)

If the framework includes agent documentation, copy it as templates:

```bash
if [ -d ".architecture/agent_docs" ]; then
  # Backup existing files as templates
  if [ -f ".architecture/agent_docs/workflows.md" ]; then
    cp .architecture/agent_docs/workflows.md .architecture/agent_docs/workflows.md.template
  fi

  if [ -f ".architecture/agent_docs/reference.md" ]; then
    cp .architecture/agent_docs/reference.md .architecture/agent_docs/reference.md.template
  fi

  if [ -f ".architecture/agent_docs/README.md" ]; then
    cp .architecture/agent_docs/README.md .architecture/agent_docs/README.md.template
  fi

  echo "✅ Agent docs backed up as templates"
fi
```

### Create Agent Documentation Files

Create three core documentation files:

**1. workflows.md** - Procedural documentation:
- Setup procedures (Claude Skills, Direct Clone, MCP)
- Architecture review process
- ADR creation workflow
- Implementation with methodology
- Step-by-step instructions for common tasks

**2. reference.md** - Reference documentation:
- Pragmatic mode details and intensity levels
- Recalibration process
- Advanced configuration options
- Troubleshooting guide
- Configuration examples

**3. README.md** - Navigation guide:
- Progressive disclosure explanation
- Quick navigation table (task → section)
- How to find information
- When to read which document

**Content Guidelines**:
- AGENTS.md: ~400 lines, always-relevant overview
- agent_docs/: Task-specific details loaded as needed
- Keep workflows procedural and actionable
- Reference should be comprehensive but organized
- README should help users navigate effectively

---

## Cleanup Procedures

With selective copying (Step 1), most cleanup is unnecessary. The main task is removing the clone directory's `.git/`.

### Verify No Framework Cruft

If you accidentally copied everything, remove these:

```bash
# Framework internal docs (should not exist if Step 1 followed correctly)
rm -f .architecture/deferrals.md
rm -f .architecture/documentation-*.md
rm -f .architecture/instruction-counting-methodology.md
rm -f .architecture/quarterly-review-process.md
rm -f .architecture/recalibration_process.md

# Framework example ADRs (numbered ADR-00X files)
rm -f .architecture/decisions/adrs/ADR-0*.md
rm -f .architecture/decisions/adrs/example-*.md

# Framework decision exploration docs
rm -f .architecture/decisions/*.md

# Framework example reviews
rm -f .architecture/reviews/0-*.md
rm -f .architecture/reviews/example-*.md
rm -f .architecture/reviews/feature-*.md
rm -f .architecture/reviews/claude-md-*.md
rm -f .architecture/reviews/pragmatic-*.md
rm -f .architecture/reviews/progressive-*.md
rm -f .architecture/reviews/readme-*.md

# Framework comparison and recalibration content
rm -rf .architecture/comparisons/*
rm -rf .architecture/recalibration/*

# Root-level framework files (should not have been copied)
rm -f AGENTS.md
rm -rf .coding-assistants/

echo "✅ Framework cruft removed"
```

### Remove Framework Git Repository

**⚠️  CRITICAL SAFEGUARDS - READ CAREFULLY**

Removing `.git` directory is destructive. Follow these safeguards:

#### Safeguard 1: Verify Project Root

```bash
# Check we're in project root (NOT in .architecture/)
if [ ! -f "package.json" ] && [ ! -f ".git/config" ] && [ ! -f "Gemfile" ]; then
  echo "❌ ERROR: Not in project root. Stopping."
  echo "   Current directory: $(pwd)"
  exit 1
fi

echo "✅ Verified in project root"
```

#### Safeguard 2: Verify Target Exists

```bash
# Check .architecture/.git exists before attempting removal
if [ ! -d ".architecture/.git" ]; then
  echo "✅ No .git directory to remove"
  exit 0
fi

echo "⚠️  Found .architecture/.git - proceeding with verification"
```

#### Safeguard 3: Verify It's the Template Repo

```bash
# Verify .git/config contains template repository URL
if ! grep -q "ai-software-architect" .architecture/.git/config 2>/dev/null; then
  echo "❌ ERROR: .architecture/.git doesn't appear to be template repo"
  echo "   Found config:"
  cat .architecture/.git/config 2>/dev/null || echo "   (could not read config)"
  echo ""
  echo "⛔ STOPPING - User confirmation required"
  exit 1
fi

echo "✅ Verified template repository"
```

#### Safeguard 4: Use Absolute Path

```bash
# Get absolute path (never use relative paths with rm -rf)
ABS_PATH="$(pwd)/.architecture/.git"

echo "Removing: $ABS_PATH"

# Verify path is what we expect
if [[ "$ABS_PATH" != *"/.architecture/.git" ]]; then
  echo "❌ ERROR: Path doesn't match expected pattern"
  echo "   Path: $ABS_PATH"
  exit 1
fi

echo "✅ Path verified"
```

#### Safeguard 5: Execute Removal

```bash
# Remove with absolute path (no wildcards!)
rm -rf "$ABS_PATH"

# Verify removal
if [ ! -d ".architecture/.git" ]; then
  echo "✅ Template .git removed successfully"
else
  echo "⚠️  .git directory still exists"
fi
```

**Complete Safe Removal Script**:

```bash
#!/bin/bash
# Safe removal of template repository .git directory

set -e  # Exit on any error

echo "=== Safe .git Removal ==="

# 1. Verify project root
if [ ! -f "package.json" ] && [ ! -f ".git/config" ] && [ ! -f "Gemfile" ]; then
  echo "❌ Not in project root"
  exit 1
fi

# 2. Check target exists
if [ ! -d ".architecture/.git" ]; then
  echo "✅ No .git to remove"
  exit 0
fi

# 3. Verify template repo
if ! grep -q "ai-software-architect" .architecture/.git/config 2>/dev/null; then
  echo "❌ Not template repo - STOPPING"
  exit 1
fi

# 4. Get absolute path
ABS_PATH="$(pwd)/.architecture/.git"

# 5. Verify path pattern
if [[ "$ABS_PATH" != *"/.architecture/.git" ]]; then
  echo "❌ Unexpected path - STOPPING"
  exit 1
fi

# 6. Execute removal
echo "Removing: $ABS_PATH"
rm -rf "$ABS_PATH"

# 7. Verify success
if [ ! -d ".architecture/.git" ]; then
  echo "✅ Successfully removed"
else
  echo "❌ Removal failed"
  exit 1
fi
```

---

## Troubleshooting

### Common Issues

**Issue**: "Framework not found at .architecture/.architecture"
- **Cause**: Framework not cloned
- **Solution**: `git clone https://github.com/codenamev/ai-software-architect .architecture/.architecture`

**Issue**: "Permission denied" errors during copy
- **Cause**: Insufficient file permissions
- **Solution**: `chmod -R u+rw .architecture/`

**Issue**: "Directory already exists" during mkdir
- **Cause**: Framework already partially installed
- **Solution**: Check if framework is already set up: `ls -la .architecture/`

**Issue**: ".git removal verification failed"
- **Cause**: Safety check detected unexpected repository
- **Solution**: Manually verify `.architecture/.git/config` contains template repo URL
- **Never**: Override safety checks without understanding why they failed

**Issue**: "No project markers found"
- **Cause**: May not be in project root
- **Solution**: Verify you're in the correct directory, proceed with caution

### Verification Commands

**Check installation completeness**:
```bash
# Required directories
test -d .architecture/decisions/adrs && echo "✅ ADRs directory" || echo "❌ Missing ADRs"
test -d .architecture/reviews && echo "✅ Reviews directory" || echo "❌ Missing reviews"

# Required files
test -f .architecture/members.yml && echo "✅ Members file" || echo "❌ Missing members"
test -f .architecture/principles.md && echo "✅ Principles file" || echo "❌ Missing principles"
test -f .architecture/config.yml && echo "✅ Config file" || echo "❌ Missing config"
```

**Check for leftover framework files**:
```bash
# These should NOT exist after proper setup
test -d .architecture/.architecture && echo "⚠️  Clone directory still present"
test -d .architecture/.git && echo "⚠️  Template .git still present"
test -f .architecture/deferrals.md && echo "⚠️  Framework deferrals.md present"
test -f AGENTS.md && echo "⚠️  Framework AGENTS.md present"
test -d .coding-assistants && echo "⚠️  .coding-assistants folder present"
ls .architecture/decisions/adrs/ADR-0*.md 2>/dev/null && echo "⚠️  Framework example ADRs present"
```

### Recovery

**If installation fails mid-process**:
1. Remove partial installation: `rm -rf .architecture/` (if nothing important there yet)
2. Re-clone framework: `git clone https://github.com/codenamev/ai-software-architect .architecture/.architecture`
3. Start over from Step 1

**If you accidentally removed the wrong .git**:
- If it was your project's .git: **Restore from backup immediately**
- If you don't have a backup: Recovery may not be possible
- This is why the safeguards are critical

---

## Post-Installation

After installation is complete:

1. **Verify setup**: Run `"What's our architecture status?"`
2. **Review customizations**: Check `.architecture/members.yml` and `.architecture/principles.md`
3. **Run initial analysis**: The setup process creates an initial system analysis
4. **Create first ADR**: Document an early architectural decision

For customization procedures, see [customization-guide.md](./customization-guide.md).

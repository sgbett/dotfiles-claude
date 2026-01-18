---
name: dotfiles-setup
description: Sets up dotfiles-claude from a cloned repository into ~/.claude. Use when the user asks to "setup dotfiles", "install dotfiles-claude", or "/dotfiles-setup".
allowed-tools: Bash,Read,Write,Edit,Glob,AskUserQuestion
---

# Dotfiles Setup

Installs dotfiles-claude components from a cloned repository into `~/.claude`.

## Prerequisites

The user must have already cloned the repository to a location other than `~/.claude`:
```bash
git clone https://github.com/sgbett/dotfiles-claude ~/repos/dotfiles-claude
```

## Workflow

### Step 1: Locate Source Repository

Ask the user for the path to their cloned dotfiles-claude repository:

```
Where is your dotfiles-claude clone?
Default: ~/repos/dotfiles-claude
```

Validate the path exists and contains expected files (CLAUDE.md, settings.json).

### Step 2: Check Target Directory

Verify `~/.claude` exists. If not, create it:
```bash
mkdir -p ~/.claude
```

### Step 3: Select Components

Present a checkbox selection for which components to install. Use AskUserQuestion with multiSelect: true.

**Components:**
| Component | Path | Description |
|-----------|------|-------------|
| Core config | `CLAUDE.md`, `settings.json`, `.gitignore`, `.rvmrc` | Essential configuration |
| Skills | `skills/` | User-level skills (/worktree, /new-project-rails, etc.) |
| Commands | `commands/` | Custom slash commands |
| MCP servers | `mcp/` | Custom MCP servers (ruby-fetch) |
| Playbooks | `playbooks/` | Formalised procedures |
| Documentation | `docs/`, `SKILLS.md`, `NEW-PROJECT-RAILS.md` | Reference docs |
| Speckit | `speckit/` | Spec-kit templates |

All components should be checked by default.

### Step 4: Handle Collisions

For each file/directory being installed, check if it already exists in `~/.claude`.

**If collision detected**, ask the user (per-item or batch):

```
~/.claude/skills/ already exists. How should I handle this?

Options:
- Replace: Delete existing and copy new
- Merge: Copy new files, keep existing (no overwrite)
- Skip: Don't install this component
```

For directories, offer these options. For individual files, Replace or Skip.

### Step 5: Install Components

Copy selected components based on collision resolution:

```bash
# Replace - remove existing first
rm -rf ~/.claude/<component>
cp -r <source>/<component> ~/.claude/

# Merge - copy without overwriting
cp -rn <source>/<component>/* ~/.claude/<component>/

# Skip - do nothing
```

**Core config files** (CLAUDE.md, settings.json, etc.) are handled individually:
- If exists and different: show diff, ask Replace/Skip
- If exists and same: skip silently
- If doesn't exist: copy

### Step 6: Set Up Git Tracking (Optional)

Ask if they want to track their ~/.claude with git:

```
Would you like to set up git tracking for ~/.claude?
This lets you sync changes with the dotfiles-claude repo.
```

If yes:
```bash
cd ~/.claude
git init
git remote add origin https://github.com/sgbett/dotfiles-claude
git fetch origin
git reset origin/master
git branch -m master
git branch --set-upstream-to=origin/master master
```

### Step 7: Report Results

```
✓ Dotfiles setup complete

Installed components:
  ✓ Core config (CLAUDE.md, settings.json, .gitignore, .rvmrc)
  ✓ Skills (10 skills)
  ✓ Commands (6 commands)
  ✓ MCP servers (ruby-fetch)
  ✓ Playbooks (3 playbooks)
  ✓ Documentation (4 docs)
  ✗ Speckit (skipped)

Git tracking: Enabled

Next steps:
  - Review ~/.claude/CLAUDE.md and customise for your preferences
  - Check ~/.claude/SKILLS.md for available skills
  - Run /help to see available commands
```

## Error Handling

| Error | Resolution |
|-------|------------|
| Source path doesn't exist | Ask for correct path |
| Source missing expected files | Warn, confirm it's the right repo |
| Permission denied | Suggest checking permissions |
| Git init fails | Continue without git tracking, warn user |

## Notes

- Never overwrite `.credentials.json`, `history.jsonl`, `projects/`, `plugins/`, or other runtime data
- The `.gitignore` from the repo protects these files
- For merge operations, existing files take precedence (no overwrite)

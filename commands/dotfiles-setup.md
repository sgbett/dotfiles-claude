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
| Core config | `CLAUDE.md`, `settings.json`, `.gitignore` | Essential configuration |
| Profiles | `profiles/` | Practice bundles that `CLAUDE.md` imports — install with Core config, or its `@import`s dangle |
| Agents | `agents/` | Sub-agent definitions (white-hat, technical-analyst) |
| Skills | `skills/`, `scripts/vendor-setup.sh` | User-level skills (/new-project-rails, etc.) and the script that clones the vendored architecture skills |
| Commands | `commands/` | Custom slash commands |
| MCP servers | `mcp/` | Custom MCP servers (ruby-fetch) |
| Playbooks | `playbooks/` | Formalised procedures |
| Documentation | `docs/`, `SKILLS.md`, `NEW-PROJECT-RAILS.md` | Reference docs |

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
cp -RP <source>/<component> ~/.claude/

# Merge - copy without overwriting
cp -RPn <source>/<component>/* ~/.claude/<component>/

# Skip - do nothing
```

Use `-RP`, never `-r`: `-P` copies symlinks as symlinks, whereas macOS `cp -r` follows them. That would turn the vendored skill links in `skills/` into copies of whatever the source clone's `vendor/` holds (or drop them when it has none), outside the pin. On macOS a Merge's `cp -RPn` exits 1 whenever it skips an existing entry; that's the point of a Merge, not a failure.

**Core config files** (CLAUDE.md, settings.json, etc.) are handled individually:
- If exists and different: show diff, ask Replace/Skip
- If exists and same: skip silently
- If doesn't exist: copy

`scripts/vendor-setup.sh` (part of Skills) is handled the same way, into `~/.claude/scripts/` (`mkdir -p` it first).

### Step 6: Set Up Vendored Skills

If Skills was installed (Replace or Merge), the architecture skills in `~/.claude/skills/` (`architecture-review`, `specialist-review` and the rest) are symlinks into `~/.claude/vendor/ai-software-architect`, which doesn't exist yet on a fresh machine. Set it up in three checks: if check 1 fails, skip check 2; run check 3 either way.

**1. The installed script is the repository's.** If the user kept their own `~/.claude/scripts/vendor-setup.sh` in Step 5, its pin isn't the repository's:

```bash
cmp -s <source>/scripts/vendor-setup.sh ~/.claude/scripts/vendor-setup.sh
```

If this fails, don't run the script. Warn the user that the installed `vendor-setup.sh` isn't the pinned one, and report the vendored skills as not set up.

**2. Run it in the target:**

```bash
bash ~/.claude/scripts/vendor-setup.sh
```

- **Exit 0:** it cloned the pinned fork, or the existing clone is already at the pin.
- **Exit 1, existing clone:** `~/.claude/vendor/ai-software-architect` is off the pin (another `origin`, another commit, or uncommitted changes). Show the user the script's output, which names each failed check and the commands to fix it. Don't run those commands or change the clone — that's the user's call.
- **Exit 1, no clone:** the clone failed (network, or the pin isn't on the fork's `main`) and the script left nothing behind. Show the user its output; the architecture skills won't resolve until it succeeds.

**3. Every vendored skill is the source's symlink and resolves.** A Merge keeps whatever was already in `~/.claude/skills/`, such as a real directory from an earlier `cp -r`, which the pin doesn't govern:

```bash
[ -L ~/.claude/skills ] && echo "not installed: ~/.claude/skills is itself a symlink"
for src in <source>/skills/*; do
  [ -L "$src" ] || continue
  dst=~/.claude/skills/$(basename "$src")
  [ -L "$dst" ] && [ "$(readlink "$dst")" = "$(readlink "$src")" ] && [ -e "$dst" ] \
    || echo "not linked to the pinned clone: $dst"
done
```

It prints nothing when every link is right. Otherwise list what it printed for the user and don't report the pin; a wrong entry is fixed by removing it and copying the source's link (`cp -RP <source>/skills/<name> ~/.claude/skills/`), which is the user's call.

### Step 7: Set Up Git Tracking (Optional)

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

### Step 8: Report Results

```
✓ Dotfiles setup complete

Installed components:
  ✓ Core config (CLAUDE.md, settings.json, .gitignore)
  ✓ Profiles
  ✓ Agents
  ✓ Skills
  ✓ Commands
  ✓ MCP servers (ruby-fetch)
  ✓ Playbooks
  ✓ Documentation

Vendored skills: ai-software-architect at its pin
Git tracking: Enabled

Next steps:
  - Review ~/.claude/CLAUDE.md and customise for your preferences
  - Check ~/.claude/SKILLS.md for available skills
  - Run /help to see available commands
```

Report "at its pin" only when all three Step 6 checks passed. Otherwise the line says which failed: the installed script isn't the repository's (not run), the clone is off the pin or failed (with the script's output), or the skills listed by check 3 aren't linked to the pinned clone.

## Error Handling

| Error | Resolution |
|-------|------------|
| Source path doesn't exist | Ask for correct path |
| Source missing expected files | Warn, confirm it's the right repo |
| Permission denied | Suggest checking permissions |
| Git init fails | Continue without git tracking, warn user |
| Installed `vendor-setup.sh` differs from the source's | Don't run it; warn that it isn't the pinned script (Step 6) |
| `vendor-setup.sh` exits 1 | Show its output; never change the vendor clone (Step 6) |
| A vendored skill isn't the source's symlink | List it; don't report the pin (Step 6) |

## Notes

- Never overwrite `.credentials.json`, `history.jsonl`, `projects/`, `plugins/`, or other runtime data
- The `.gitignore` from the repo protects these files
- For merge operations, existing files take precedence (no overwrite)

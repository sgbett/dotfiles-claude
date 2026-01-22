# Setting up dotfiles-claude

Two ways to install these dotfiles, depending on whether you want to manage them as a git repo.

## Option A: Clone directly into ~/.claude (recommended for contributors)

Clone the repository directly to `~/.claude`. This gives you a fully git-tracked configuration that you can push changes back to.

```bash
# Back up any existing config
mv ~/.claude ~/.claude.backup

# Clone directly
git clone https://github.com/sgbett/dotfiles-claude ~/.claude

# Restore any runtime data you want to keep
cp ~/.claude.backup/.credentials.json ~/.claude/
cp ~/.claude.backup/history.jsonl ~/.claude/
cp -r ~/.claude.backup/projects ~/.claude/
```

**Pros:** Full git integration, easy to contribute changes back
**Cons:** Must back up/restore existing runtime data manually

---

## Option B: Use /dotfiles-setup command (recommended for users)

Clone the repository to your preferred location, then use the setup command to install components selectively.

```bash
# Clone to your repos folder
git clone https://github.com/sgbett/dotfiles-claude ~/repos/dotfiles-claude

# Open Claude Code and run the setup command
claude
/dotfiles-setup
```

The command will:
1. Ask for your clone location
2. Let you select which components to install (checkboxes)
3. Handle collisions (replace/merge/skip)
4. Optionally set up git tracking

**Pros:** Selective installation, handles existing files gracefully, preserves runtime data
**Cons:** Requires Claude Code to be running

---

## Vendor dependencies

Some commands and skills are symlinked from external repos in `vendor/` (gitignored). After cloning, run:

```bash
./scripts/vendor-setup.sh
```

This clones:
- [sbusso/claude-workflow](https://github.com/sbusso/claude-workflow) — `/plan:*`, `/do:*`, and related commands
- [codenamev/ai-software-architect](https://github.com/codenamev/ai-software-architect) — architecture review skills
- [github/spec-kit](https://github.com/github/spec-kit) — `/speckit:*` specification commands

To update vendors:
```bash
for repo in claude-workflow ai-software-architect spec-kit; do
  git -C vendor/$repo pull
done
```

---

## What gets installed

| Item | Description |
|------|-------------|
| `CLAUDE.md` | Personal instructions loaded into every session |
| `SKILLS.md` | Skills reference documentation |
| `NEW-PROJECT-RAILS.md` | Rails project setup guide |
| `settings.json` | MCP server configuration |
| `skills/` | User-level skills (invoke with `/skill-name`) |
| `commands/` | Custom slash commands |
| `mcp/` | Custom MCP servers |
| `playbooks/` | Formalised procedures |
| `docs/` | Reference documentation |
| `speckit/` | Spec-kit templates |
| `.rvmrc` | Ruby version (rvm) |

## What gets preserved

Your existing runtime data remains untouched (protected by `.gitignore`):
- `.credentials.json` - Authentication credentials
- `history.jsonl` - Command history
- `cache/` - Cached data
- `projects/` - Project-specific settings
- `plugins/` - Installed plugins
- `specs/` - Project specifications

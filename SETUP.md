# Setting up dotfiles-claude

These dotfiles can be merged into an existing `.claude` directory without overwriting your credentials, history, or other runtime data.

## Installation

1. Clone the repository to a temporary location:
   ```bash
   git clone --depth 1 https://github.com/sgbett/dotfiles-claude /tmp/dotfiles-claude
   ```

2. Copy the contents into your `.claude` directory:
   ```bash
   cp -r /tmp/dotfiles-claude/* /tmp/dotfiles-claude/.gitignore ~/.claude/
   ```

3. Clean up the temporary clone:
   ```bash
   rm -rf /tmp/dotfiles-claude
   ```

4. Set up git tracking to keep your config in sync with the repo:
   ```bash
   cd ~/.claude
   git init
   git remote add origin https://github.com/sgbett/dotfiles-claude
   git fetch origin
   git reset origin/master
   git branch -m master
   git branch --set-upstream-to=origin/master master
   ```

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
| `specs/` | Project specifications |
| `.rvmrc` | Ruby version (rvm) |

## What gets preserved

Your existing runtime data remains untouched:
- `.credentials.json` - Authentication credentials
- `history.jsonl` - Command history
- `cache/` - Cached data
- `projects/` - Project-specific settings
- `plugins/` - Installed plugins

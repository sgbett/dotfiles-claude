# Claude Code Configuration

Personal configuration for [Claude Code](https://claude.ai/code).

## Contents

- `settings.json` - MCP server configuration
- `mcp/` - Custom MCP servers
  - `ruby-fetch/` - Ruby-based web fetch server
- `commands/` - Custom slash commands
  - `project/plan/tasks.md` - GitHub Issue breakdown (from claude-workflow)
  - `speckit/` - Specification commands (from spec-kit)
- `speckit/` - Spec-kit templates
- `plans-reference/` - Reference documentation
- `playbooks/` - Formalised procedures

## What Claude Code Auto-Loads

When starting a session in **any project**, Claude Code automatically injects:

| File | Behaviour |
|------|-----------|
| `CLAUDE.md` | Always loaded into context |
| `rules/*.md` | Always loaded (if directory exists) |
| `settings.json` | Applied as configuration |

Everything else requires explicit action:

| File/Folder | Requires |
|-------------|----------|
| `INSTALLING-RAILS.md` | Read tool or `@` import |
| `playbooks/*.md` | Read tool or `@` import |
| `plans-reference/*.md` | Read tool or `@` import |
| `skills/` | Invoke with `/skill-name` |
| `commands/` | Invoke with `/command-name` |

**Tip**: Reference files in `CLAUDE.md` (e.g., "Follow `~/.claude/INSTALLING-RAILS.md`") without importing them. They'll only be read when needed, keeping context lean.

## Setup on New Machine

1. Clone this repo to `~/.claude`:
   ```bash
   git clone git@github.com:USERNAME/dotfiles-claude.git ~/.claude
   ```

2. Install external dependencies (optional):
   - [ai-software-architect](https://github.com/codenamev/ai-software-architect) skills

## What's NOT Tracked

See `.gitignore` for full list. Key exclusions:
- `history.jsonl` - conversation history
- `projects/` - per-project memory
- `debug/`, `todos/`, `plans/` - ephemeral session data (working memory)
- `skills/` - ai-software-architect (reinstall from external repo)

**Note**: `plans/` is working memory (gitignored), while `plans-reference/` and `playbooks/` are tracked. See `plans-reference/plan-organization-guidelines.md` for the distinction.

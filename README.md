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

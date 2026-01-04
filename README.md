# Claude Code Configuration

Personal configuration for [Claude Code](https://claude.ai/code).

## Contents

- `settings.json` - MCP server configuration
- `mcp/` - Custom MCP servers
  - `ruby-fetch/` - Ruby-based web fetch server

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
- `debug/`, `todos/`, `plans/` - ephemeral session data
- `skills/` - installed from external repos

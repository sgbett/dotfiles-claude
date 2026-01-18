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
| `NEW-PROJECT-RAILS.md` | Read tool or `@` import |
| `playbooks/*.md` | Read tool or `@` import |
| `skills/` | Invoke with `/skill-name` |
| `commands/` | Invoke with `/command-name` |

**Tip**: Reference files in `CLAUDE.md` (e.g., "Follow `~/.claude/NEW-PROJECT-RAILS.md`") without importing them. They'll only be read when needed, keeping context lean.

## Setup on New Machine

1. Clone this repo to `~/.claude`:
   ```bash
   git clone git@github.com:sgbett/dotfiles-claude.git ~/.claude
   ```

2. Install [ai-software-architect](https://github.com/codenamev/ai-software-architect) skills (required for `playbooks/development-workflow.md`):
   ```bash
   git clone https://github.com/codenamev/ai-software-architect /tmp/ai-architect-$$
   cp -r /tmp/ai-architect-$$/.claude/skills ~/.claude/
   ```

   This provides the following skills used by the development workflow:
   - `architecture-review` — multi-specialist architectural review
   - `specialist-review` — focused domain expert review
   - `create-adr` — document architectural decisions
   - `pragmatic-guard` — YAGNI enforcement

## What's NOT Tracked

See `.gitignore` for full list. Key exclusions:
- `history.jsonl` - conversation history
- `projects/` - per-project memory
- `debug/`, `todos/`, `plans/` - ephemeral session data (working memory)
- `skills/` - ai-software-architect (reinstall from external repo)

**Note**: `plans/` is working memory (gitignored), while `playbooks/` is tracked. See `playbooks/plan-management.md` for the plan lifecycle.

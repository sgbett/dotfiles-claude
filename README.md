# Claude Code Configuration

Personal configuration for [Claude Code](https://claude.ai/code).

## Contents

- `settings.json` - MCP server configuration
- `profiles/` - Shareable practice bundles imported by `CLAUDE.md` (`git-workflow.md`, `work-organisation.md`)
- `agents/` - Sub-agent definitions (`white-hat`, `technical-analyst`)
- `mcp/` - Custom MCP servers
  - `ruby-fetch/` - Ruby-based web fetch server
- `commands/` - Custom slash commands
  - `plan/tasks.md` - `/plan:tasks`, a tracked copy adapted from [claude-workflow](https://github.com/sbusso/claude-workflow) (attribution and licence in the file)
  - `project/` - `/project:generate`
  - Standalone: `/transcript`, `/dotfiles-setup`, `/deslop`, `/config-cleaner`
- `vendor/` - Upstream repos (gitignored)
  - `ai-software-architect/` - [codenamev/ai-software-architect](https://github.com/codenamev/ai-software-architect)
- `skills/` - User-level skills (symlinked from `vendor/` where noted)
  - Architecture skills → ai-software-architect (`/setup-architect`, `/architecture-review`, `/specialist-review`, etc.)
  - Custom skills: `/new-project-rails`, `/repo-security-*`, etc.
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

## Setup

See **[SETUP.md](SETUP.md)** for installation options:

- **Option A:** Clone directly to `~/.claude` (for contributors)
- **Option B:** Use `/dotfiles-setup` command (for users) — selective installation with collision handling

## What's NOT Tracked

See `.gitignore` for full list. Key exclusions:
- `history.jsonl` - conversation history
- `projects/` - per-project memory
- `debug/`, `todos/`, `plans/` - ephemeral session data (working memory)

**Note**: `plans/` is working memory (gitignored), while `playbooks/` is tracked. See `playbooks/workflow-guide.md` for the plan lifecycle.

## Attribution

This project incorporates work from:

- **[ai-software-architect](https://github.com/codenamev/ai-software-architect)** — Architecture review skills, ADR creation, specialist reviews
- **[claude-workflow](https://github.com/sbusso/claude-workflow)** — Task breakdown command (`/plan:tasks`), tracked as a copy with one local change (MIT; notice in `commands/plan/tasks.md`)

## Reference Documentation

The `docs/` folder contains reference guides:

- `spotlight.md` - macOS Spotlight re-indexing commands
- `terminal-basics.md` - Terminal fundamentals
- `wsl-git.md` - Git configuration for WSL

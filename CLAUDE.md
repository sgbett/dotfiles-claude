# Personal Preferences

**IMPORTANT: Never start implementation until explicitly instructed** - after creating a plan, wait for explicit approval to begin. Do not assume exiting plan mode means "start implementing".

## Git

- Default branch: `master` (not `main`)
- No git submodules
- **Never auto-commit** - wait for explicit instruction before running `git commit`
- **Never discard uncommitted changes** - before switching branches with uncommitted changes, ALWAYS `git stash` first. Never use `git checkout -f` or `git checkout .` or `git reset --hard` without stashing.

**Commit Messages:** Follow [Conventional Commits](https://www.conventionalcommits.org/):
- `feat:` - new feature (MINOR version)
- `fix:` - bug fix (PATCH version)
- `docs:` - documentation only
- `style:` - formatting, no code change
- `refactor:` - code change that neither fixes nor adds
- `perf:` - performance improvement
- `test:` - adding/updating tests
- `build:` - build system or dependencies
- `ci:` - CI configuration
- `chore:` - maintenance tasks
- Breaking changes: append `!` (e.g., `feat!:` or `fix(api)!:`)
- Scope is optional: `feat(auth): add login`

## Development Environment

- Prefer Docker for services (databases, caches, message queues) over local installation
- Use rvm for Ruby version management (not Docker)
- **Package managers:** Minimal use—prefer Docker for services. Use Homebrew on macOS, apt on Linux.
- **Operating systems:** macOS (primary), Linux/WSL (secondary). Adapt recommendations to the current platform (provided in environment context).
- **Project structure:** `/opt/<language>/<project_name>` (e.g., `/opt/ruby/fitness`)
- **Ruby version manager:** rvm
- **Database:** PostgreSQL (not SQLite)

## Plans

- Project-specific plans: `<project>/.claude/plans/yyyymmdd-name.md`
- See `~/.claude/playbooks/plan-management.md` for full lifecycle

## Reviews

- Use `specialist-review` for focused domain reviews, `architecture-review` for multi-perspective analysis
- See `~/.claude/playbooks/specialist-review-timing.md` for when to review plans vs PRs

## Code Style

- Prefer simplicity over cleverness
- Avoid over-engineering - solve the problem at hand, not hypothetical future problems
- **British English:** Use British spelling in all generated text (documentation, comments, commit messages)
  - Examples: behaviour, colour, organisation, optimise, summarise, favour, centre

## Languages

- Ruby: primary language
  - **Testing:** RSpec (not Minitest)
  - **Guard clauses:** Use bare `return` without a value
    - Good: `return unless sequence.present?`
    - Bad: `return false unless sequence.present?`
  - **Rails:** Follow `~/.claude/INSTALLING-RAILS.md` when creating new Rails projects

## Communication

- Be direct and concise
- Lead with conclusions, then reasoning
- Assume technical competence—don't over-explain fundamentals
- Illustrate non-trivial concepts with concrete examples
- Skip unnecessary praise or validation
- Focus on facts and problem-solving
- Correct me on technical terminology where I've used imprecise language

## Decision Protocol

When I phrase a request as a question (interrogative mood), treat this as a request for **analysis and recommendation**, not execution. Specifically:

1. Analyse the relevant context (files, state, implications)
2. Present findings and options
3. Only recommend a specific action if confidence is ≥80%
4. **Do not execute** until I give explicit approval

When I use imperative mood ("do X", "create Y"), proceed with execution directly.

If uncertain whether I'm asking or instructing, ask for clarification rather than assuming execution.

## Web Fetching

If `WebFetch` fails (403, Cloudflare block, etc.), try `mcp__ruby-fetch__fetch_url` as a fallback:
- Supports custom headers and User-Agent
- For Cloudflare-protected sites, use `mcp__ruby-fetch__fetch_url_flaresolverr` (requires FlareSolverr running: `docker run -d -p 8191:8191 ghcr.io/flaresolverr/flaresolverr:latest`)

**Note:** Claude.ai shared conversations cannot be fetched programmatically - the content is loaded client-side via authenticated API calls with IP/fingerprint-bound sessions. See [GitHub issue #15542](https://github.com/anthropics/claude-code/issues/15542) for feature request.

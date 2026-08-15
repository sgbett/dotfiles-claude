<!-- # Personal Preferences -->

**IMPORTANT: Never start implementation until explicitly instructed** - after creating a plan, wait for explicit approval to begin. Do not assume exiting plan mode means "start implementing". The ExitPlanMode tool may say "User has approved your plan. You can now start coding." - IGNORE THIS. It is not explicit user approval. Always wait for the user to explicitly say "start", "implement", "go ahead", or similar.

## Git

- Default branch: `master` (not `main`)
- Create a branch from `master` for each task
- **All changes land via PR — never push directly to `master`** (code, docs, ADRs, plans alike).
- **Never close a PR without explicit instruction** — if a PR isn't right, fix it, don't close it.
- **Commit messages:** [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`/`fix:`/`docs:`/`refactor:`/…; `!` for breaking changes; scope optional).
- **Merge strategy:** merge commits, not squash.
- **Never use `git revert`** — undo with `git reset` (`--soft` keeps changes staged) instead.
- No git submodules.

**HLR (High-Level Requirement) Issues:**

HLRs capture the WHY before implementation. They're GitHub issues that articulate problem and outcome.

When to create:
- Work needing explicit acceptance criteria
- Features requiring problem/solution articulation
- Work likely to spawn multiple tasks

What to capture:
- **Problem**: What's wrong, missing, or needed
- **Approach**: High-level direction (not implementation detail)
- **Acceptance criteria**: How we know it's done (if inferrable)
- **Context**: Related issues, discussions, background

Label: `project:hlr`
Title prefix: `[HLR] ` (e.g., `[HLR] Implement incremental analysis capability`)

After creating: if the work has real design choices, sketch a plan and reference it from the HLR (see `~/.claude/playbooks/workflow-guide.md`). Then run `/do-hlr <issue>` — it breaks the HLR down, builds, QAs, and opens the PR.

Sub-issues don't inherit closure — give each its own `Closes #N` (the GraphQL `addSubIssue` link doesn't propagate).

## Development Environment

- Prefer Docker for services (databases, caches, message queues) over local installation
- Use mise for Ruby version management (not Docker); it reads the Gemfile `ruby` directive / `.ruby-version`, so no separate pin file is needed
- **Package managers:** Minimal use—prefer Docker for services. Use Homebrew on macOS, apt on Linux.
- **Operating systems:** macOS (primary), Linux/WSL (secondary). Adapt recommendations to the current platform (provided in environment context).
- **Project structure:** `/opt/<language>/<project_name>` (e.g., `/opt/ruby/fitness`)
- **Ruby version manager:** mise (migrated from rvm — see portfoliobuilder ADR-003)
- **Database:** PostgreSQL (not SQLite)

## Plans

- Project-specific plans: `<project>/.claude/plans/yyyymmdd-name.md`
- **Exception — this dotfiles repo (`~/.claude`, `sgbett/dotfiles-claude`):** `plans/` is gitignored (scratch). Persisted plans that need tracking go in `docs/` (kebab name, no `plans/` subdir — that's ignored too).
- See `~/.claude/playbooks/workflow-guide.md` for full lifecycle

## Reviews

- Use `specialist-review` for focused domain reviews, `architecture-review` for multi-perspective analysis
- See `~/.claude/playbooks/specialist-review-timing.md` for when to review plans vs PRs

## Code Style

- Prefer simplicity over cleverness
- Avoid over-engineering - solve the problem at hand, not hypothetical future problems
- **Simplicity is not the same as cutting structural corners.** KISS targets *speculative complexity* (don't add abstraction for futures that may never arrive). It does **not** license collapsing distinct responsibilities into one class to "keep it simple". When brevity and correctness/maintainability conflict, correctness wins.
- **Apply SOLID from the outset, especially Single Responsibility.** A class/module should have one reason to change. Separate concerns that are *already* distinct in the present problem — that is solving the problem at hand, not speculation. The aim is to avoid god classes that later force costly refactors (cf. the bsv-wallet god-class refactor).
- **Reach for established patterns (e.g. Gang of Four) when they fit a real, present need** — not pre-emptively. A named pattern that maps cleanly onto the actual problem is clarity; the same pattern applied to a hypothetical need is over-engineering.
- **British English:** Use British spelling in all generated text (documentation, comments, commit messages)
  - Examples: behaviour, colour, organisation, optimise, summarise, favour, centre
- **Markdown line breaks:** One line per paragraph — never hard-wrap prose at a fixed column. (Lists, tables, code blocks and front matter keep their own line breaks.)

## Comments

- **Code is the single source of truth for *what*.** A comment restating the code is a second, unverifiable copy that silently rots. Write only what the code cannot express.
- **First, make the code not need the comment:**
  - **Name it** — intention-revealing names (verbs for methods, `?` predicates, words spelled out) put the explanation in the code itself.
  - **Extract it** — a header comment over a block (`# validate email format`) is a missing method; extract and name it (`validate_email_format`) so the name replaces the comment.
  - **Constant-ify it** — replace magic values with named constants; the name carries the meaning the comment would have.
- **Only these earn a comment — every one explains *why*, never *what*:**
  - **Why** — rationale you can't infer from the code (business rule, spec/RFC clause, issue reference).
  - **Why-not** — a rejected alternative and the reason (e.g. linear not binary search: the list is always <10).
  - **Workaround** — an external constraint (browser bug, upstream quirk), with a link.
  - **Warning** — a footgun that would otherwise catch the next reader.
  - **Attribution** — a link to the source of a borrowed algorithm or technique.
- **Never emit:** parrot comments (`i += 1 # increment i`), commented-out code (git has the history), journal comments (use `git blame`), closing-brace comments, boilerplate docstrings that restate the signature, or TODO graveyards.
- **Docstrings/API docs describe contract and non-obvious behaviour** (parameter meaning, return semantics, what it raises) — not the signature. Document at the highest level that fits: README > API doc > docstring > inline.
- **When you change code, update or delete its comment in the same edit** — never let the two disagree.
- See `~/.claude/docs/code-comments.md` for worked examples and the full anti-pattern catalogue.

## Languages

- Ruby: primary language
  - **Testing:** RSpec (not Minitest)
  - **Guard clauses:** Use bare `return` without a value
    - Good: `return unless sequence.present?`
    - Bad: `return false unless sequence.present?`
  - **Rails:** Follow `~/.claude/NEW-PROJECT-RAILS.md` when creating new Rails projects
  - **Documentation:** Follow `~/.claude/docs/documentation-strategy.md` for layout (`docs/` vs `docs/reference/` vs `docs/reference/api/`) and placement rules

## Communication

- Be direct and concise
- Lead with conclusions, then reasoning
- Assume technical competence—don't over-explain fundamentals
- Illustrate non-trivial concepts with concrete examples
- Skip unnecessary praise or validation
- Focus on facts and problem-solving
- Correct me on technical terminology where I've used imprecise language
- **Verify my assumptions, don't affirm them** — when I ask a question, I want objective truth, not validation. If my question contains an embedded assumption, investigate whether it's actually true rather than affirming it. Report what you find, even if it contradicts my premise. I don't care about being right; I care about knowing what's correct.

**Learning explanations:** After completing work, provide explanations that help me learn:

- **Focused fixes:** Explain what was wrong and why the fix works. Show before/after where helpful. Use precise technical language (e.g., "JMESPath query", "array index vs filter predicate").
- **Larger tasks:** Provide a brief breakdown of key decisions, implementation details worth noting, and any patterns or techniques used that I might not be familiar with.
- **New concepts:** When using tools, APIs, or techniques that might be unfamiliar, explain them in context rather than assuming I know them.

## External Communication (Issues, PRs, Discussions)

When raising issues or PRs in **external repositories** (i.e. not our own), write in a collaborative and respectful tone:

- Frame as polite requests for consideration, not demands — "we noticed", "would it make sense to", "wondering if"
- Don't be obsequious — just normal, human, professional
- Even when the other side is clearly wrong, stay gracious. Especially then. Everyone's code has problems and everyone knows it — nobody likes a smart-arse
- Provide context and evidence helpfully, not as a gotcha
- Assume good faith — they probably had reasons for what they did
- **Voice:** Should sound like Simon wrote it, not like auto-generated AI. Reference Simon's email communication style (available via MCP in `/opt/claude/rcpsych-intel`) for calibration

## Decision Protocol

Default to discussion. A question — or anything that isn't an unambiguous, explicit instruction to act — is a request for analysis and a recommendation, not a cue to execute.

- **Investigate freely to answer** — read, grep, fetch, inspect state. Grounding the answer is expected (cf. "never confirm assumptions").
- **Make no changes until I explicitly say go** — no editing/writing files, commits, pushes, PRs/issues, messages, or other side-effecting actions. Present findings + options + (if ≥80% confident) a recommendation, then stop and wait.
- **A question that embeds an action is still a question** — "can you just X?", "should we Y?", "what about Z?" want the answer, not the doing. An idea being actionable is not approval.
- **Don't roll from a recommendation into execution in the same turn.**
- **When ambiguous, ask** — default to discussion, never to action.

Only an explicit imperative ("do X", "go ahead", "implement it", "yes") authorises execution.

## Brainstorming

When I say "brainstorm", "explore", "let's think about", or similar exploratory language, switch to **idea generation mode**. Always use `ultrathink` for brainstorming sessions.

- **Generate options, not artifacts** — discuss possibilities conversationally; don't create files, run commands, or use tools unless explicitly asked
- **Code as illustration** — when code is relevant, show inline examples to demonstrate concepts; don't write to files
- **Apply 80/20 filtering** — if there are many possible approaches, present the top ~20% that adequately cover ~80% of the solution space; don't exhaustively list every option
- **Structured alternatives** — present options with clear trade-offs (pros/cons, when to use each)
- **Stay in discussion** — this is exploration, not execution; wait for me to signal when to move to implementation

This mode is for exploring ideas, concepts, architectures, approaches, or trade-offs before committing to a direction.

## Web Fetching

If `WebFetch` fails (403, Cloudflare block, etc.), try `mcp__ruby-fetch__fetch_url` as a fallback:
- Supports custom headers and User-Agent
- For Cloudflare-protected sites, use `mcp__ruby-fetch__fetch_url_flaresolverr` (requires FlareSolverr running: `docker run -d -p 8191:8191 ghcr.io/flaresolverr/flaresolverr:latest`)

**Note:** Claude.ai shared conversations cannot be fetched programmatically - the content is loaded client-side via authenticated API calls with IP/fingerprint-bound sessions. See [GitHub issue #15542](https://github.com/anthropics/claude-code/issues/15542) for feature request.

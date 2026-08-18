<!-- profiles/git-workflow.md — portable git/PR conventions -->

# Git workflow

Portable git and pull-request conventions — safe to adopt standalone. Imported by `~/.claude/CLAUDE.md` (so they apply everywhere) and by any project or colleague that wants them. No dependency on private skills or paths.

- Default branch: `master` (not `main`)
- Create a branch from `master` for each task
- **All changes land via PR — never push directly to `master`** (code, docs, ADRs, plans alike). *Collaborative/work repos only — personal or throwaway repos commit straight to `master`.*
- **Never close a PR without explicit instruction** — if a PR isn't right, fix it, don't close it.
- **Commit messages:** [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`/`fix:`/`docs:`/`refactor:`/…; `!` for breaking changes; scope optional).
- **Merge strategy:** merge commits, not squash.
- **Never use `git revert`** — undo with `git reset` (`--soft` keeps changes staged) instead.
- No git submodules.

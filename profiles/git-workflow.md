<!-- profiles/git-workflow.md — portable git/PR conventions -->

# Git workflow

Portable git and pull-request conventions — safe to adopt standalone, imported by a global or project `CLAUDE.md` or vendored verbatim into a protected repository's `.claude/rules/`, so every collaborator's checkout carries them. No dependency on private skills or paths. The source is `profiles/git-workflow.md` in sgbett/dotfiles-claude: change it there first, then every copy.

- Default branch: `master` (not `main`)
- Create a branch from `master` for each task
- **Tier.** A **protected** repository is part of the product, where the production tenants and the other committers are; any other is **personal**. The declaration is the file `.claude/rules/git-workflow.md` at the root of the repository being worked in: check that it exists, since this profile is also imported globally and having its text in context does not make a repository protected.
- **A protected repository lands every change via PR — never push directly to `master`** (code, docs, ADRs, plans alike); a personal one commits straight to `master`. A push to `master` rejected by a ruleset (GH013) means open a PR, never route around it.
- **Tier line.** A repository with a genuine difference states it in one line of its `CLAUDE.md`, `Git tier: <protected|personal>; <difference>` (`Git tier: personal; issue-tracked work goes by PR`); any other has no such line.
- **Never close a PR without explicit instruction** — if a PR isn't right, fix it, don't close it.
- **Commit messages:** [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`/`fix:`/`docs:`/`refactor:`/…; `!` for breaking changes; scope optional).
- **Merge strategy:** merge commits — never squash, never fast-forward. `git log --first-parent master` is the one-entry-per-PR view.
- **Keeping a branch current:** rebase it onto its base — never merge the base into it — and only when it conflicts or needs something the base has gained. Push with `git push --force-with-lease --force-if-includes` (a lease alone is defeated by a background fetch); any other checkout of the branch then fetches and resets to it.
- **Force-push your own branch only.** Never `master`, a release branch, a project base (`project/<id>/master`), or a branch someone else is working on: a branch with another active committer is theirs until they say otherwise, and yours again once their work on it is done.
- **Never push while auto-merge is on** — it would merge on green with nobody looking. Turn it off first (`gh pr merge --disable-auto`).
- **Cite PRs and paths, not commit hashes,** in anything that outlives a rebase — issues, checklists, PR bodies.
- **Never use `git revert`.** Work not yet landed is undone with `git reset` (`--soft` keeps changes staged); landed work is fixed forward with a new PR, since the default branch takes no rewrite.
- No git submodules.
- **Enforcement assets:** `profiles/git-workflow/` in sgbett/dotfiles-claude holds the ruleset templates and the setup runbook; a protected repository applies the templates and vendors the runbook.

# Other repositories

`/do` acts only from a checkout of this repository (the issue's) or a fork of it, and opens its PR only against this repository; `check` stops otherwise. `facts` and `check` list this file in `read` when the push remote is a fork, or the issue's parent or a sub-issue lives in another repository.

## A fork

- The conventions may push the branch to a fork you can write to (reason `fork_not_writable` otherwise) and open the PR upstream (fork → upstream); the PR still targets this repository (reason `pr_target_not_this_repository` otherwise).
- A fork you push to counts as this repository under the Visibility rule.
- `gh`'s own default repository can be the fork, so every `gh` call names this repository, as SKILL.md says; from a fork, `gh pr create` also needs `--head <owner>:<branch>`.
- Never check out, build or test another fork's branch.

## A parent or sub-issue in another repository

- It's delivered by `/do` run from its own checkout. This run tracks it, its state as GitHub gives it, but never builds, closes or comments on it.
- Its `authorAssociation` is relative to its own repository, so `bin/preflight` holds it to a stricter Trust rule: only the authenticated user, or OWNER or MEMBER when both repositories share an owner, counts, and only if nobody but its author has edited its body or title. `facts` gives each one's `trusted` and `trust_reason`.
- One still open, or by an author who isn't trusted, keeps the issue open: `record closes` leaves out the issue's `Closes` line and lists it under `held`, or under `session_only.held` if it may not be named. Name those in the session; the issue stays open for the user.

## What may be named

On GitHub — the ledger, comments, sub-issues, commits and the PR — name, link into or quote another repository only if it's public; report anything else in the session. `facts` marks the parent and each sub-issue `nameable`, and keeps one that isn't, with its reference and title, only under `session_only.not_nameable`. QA's evidence may be another repository's PR: give it in the session, and link it at step 7 only within this rule.

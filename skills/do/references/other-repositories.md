# Other repositories

`/do` acts only from a checkout of this repository (the issue's) or a fork of it, and opens its PR only against this repository.

## A fork

- The conventions may push the branch to a fork you can write to and open the PR from it; the PR still targets this repository.
- A fork you push to counts as this repository under the Visibility invariant.
- From a fork, `gh pr create` also needs `--head <owner>:<branch>`, beside the repository every `gh` call names.
- Never check out, build or test another fork's branch.

## A parent or sub-issue in another repository

- It's delivered by `/do` run from its own checkout. This run tracks it, its state as GitHub gives it, but never builds, closes or comments on it.
- Its `authorAssociation` is relative to its own repository, so `bin/preflight` trusts only the authenticated user, or OWNER or MEMBER when both repositories share an owner, and only if nobody but its author edited its body or title. `facts` gives each one's `trusted` and `trust_reason`.
- One still open, or by an author who isn't trusted, keeps the issue open: `record closes` holds the issue under `held`, with the sub-issue there or, if it may not be named, under `session_only.held`.
- `facts` marks each `nameable` under the Visibility invariant, and keeps one that isn't, with its reference and title, only under `session_only.not_nameable`.

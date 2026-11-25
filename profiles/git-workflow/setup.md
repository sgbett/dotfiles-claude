<!-- profiles/git-workflow/setup.md — one-time setup and apply procedure for the git-workflow enforcement assets -->

# Git workflow: setup

This runbook covers a collaborator's one-time setup and the procedure an admin follows to apply the enforcement assets to a repository. It does not restate the rules: those are the profile's, `profiles/git-workflow.md` in sgbett/dotfiles-claude, vendored as `.claude/rules/git-workflow.md`, which is also what declares a repository protected. For the rebase procedure, see the profile's "Keeping a branch current" line.

## What is here

| File | What it is | Where it goes |
| --- | --- | --- |
| `ruleset.json` | Body of the ruleset request that binds the default branch | Not vendored; applied by an admin |
| `ruleset-project-release.json` | Body of the ruleset request that binds project bases (`project/<id>/master`) and release branches (`releases/<version>`) | Not vendored; applied by an admin |
| `ruleset-tags.json` | Body of the ruleset request that binds every tag | Not vendored; applied by an admin |
| `repository.json` | Body of the repository-settings request that fixes the merge methods | Not vendored; applied by an admin |
| `setup.md` | This file | The repository's contributor docs, for example `docs/` |

Every vendored copy carries a first line reading `vendored from sgbett/dotfiles-claude <path>`; the rules text's is `<!-- vendored from sgbett/dotfiles-claude profiles/git-workflow.md -->` followed by a blank line. Change the source first, then every copy.

This file is vendored into contributor docs, never into `.claude/rules/`, which loads into every agent session.

## A collaborator's one-time setup

Three global git settings:

```sh
git config --global pull.rebase true
git config --global push.useForceIfIncludes true
git config --global rebase.autoStash true
```

- `pull.rebase true`: a `git pull` rebases your branch instead of creating a merge from the base.
- `push.useForceIfIncludes true`: a lease push also checks that the remote tip was seen locally, so a background fetch cannot defeat the lease.
- `rebase.autoStash true`: a rebase over a dirty tree stashes your changes and restores them afterwards.

## Applying the templates to a repository (admin)

Run these from `profiles/git-workflow/` in a checkout of sgbett/dotfiles-claude, replacing `OWNER/REPO`, in this order.

**Repository settings first.** Merge methods and the update-branch button; squash goes off and merge commits on in one request, so no intermediate state has neither.

```sh
gh api -X PATCH repos/OWNER/REPO --input repository.json
```

**Create the rulesets.** One per template: the default branch, whatever its name; project bases and release branches; tags.

```sh
gh api -X POST repos/OWNER/REPO/rulesets --input ruleset.json
gh api -X POST repos/OWNER/REPO/rulesets --input ruleset-project-release.json
gh api -X POST repos/OWNER/REPO/rulesets --input ruleset-tags.json
```

To update an existing ruleset instead, look up its id by name, then replace it whole with its template: a `PUT` does not merge.

```sh
gh api repos/OWNER/REPO/rulesets
gh api -X PUT repos/OWNER/REPO/rulesets/ID --input ruleset.json
```

**Check the effective rules.** The default branch lists `pull_request`, `non_fast_forward` and `deletion`; a project base or release branch lists `deletion` and `non_fast_forward`; a work branch beside a project base (`project/<id>/<issue>_<title>`) lists none. A branch name's slashes are written `%2F`.

```sh
gh api repos/OWNER/REPO/rules/branches/master
gh api repos/OWNER/REPO/rules/branches/project%2FPROJECT_ID%2Fmaster
```

**Remove a classic branch protection, only where one exists and adds nothing the template lacks** (no required reviews, status checks or push restrictions). Deletion is irreversible. A ruleset and a classic protection coexist, so with the ruleset created first there is no unprotected window.

```sh
gh api -X DELETE repos/OWNER/REPO/branches/master/protection
```

Why the templates are shaped as they are:

- No bypass actors: an admin bypass exempts the account the agent pushes as, which is what the rules exist to bind.
- `require_extra_approval_for_unattributed_changes` false, said outright: GitHub fills it with true when it is left out, and with no required approvals a commit whose author maps to no GitHub account would then need an approval a sole owner cannot give.
- No `required_status_checks`: each repository's CI ruleset is its own.
- Never `required_linear_history` on the default branch: on GitHub it bans merge commits.
- `~DEFAULT_BRANCH` rather than a branch name: the rule survives a rename, and a repository still on `main` is covered.
- `refs/heads/project/*/master` rather than `project/**`: `*` stops at `/`, so a project's work branches beside its base stay free to be rebased and deleted, which `project/**` would forbid.
- No `creation` rule on tags: a release tag is still pushed direct, and `update` and `deletion` stop it being moved or removed afterwards.

Rulesets on a private repository need a paid plan. The `git-settings audit` script under the `repo-consistency` skill in sgbett/dotfiles-claude reports what differs from the templates.

## Releases

A version bump is a change like any other and lands by PR. The tag is pushed directly afterwards: the tag ruleset leaves creating a tag open and rejects moving or deleting one. A release branch (`releases/<version>`) is likewise created freely and cannot then be rewritten or deleted.

## Coverage

| Case | Control |
| --- | --- |
| A direct push to the default branch, or rewriting or deleting it | The default-branch ruleset: changes land by merged PR only |
| Rewriting or deleting a project base or release branch, by push or the refs API, a lease push included | The project-and-release ruleset |
| Moving or deleting a tag | The tag ruleset |
| Overwriting commits someone else pushed to a work branch, which you have not integrated | Git's lease with `push.useForceIfIncludes` |
| The agent force-pushing, pushing a `+` refspec or `--mirror`, or changing a ruleset, a branch protection, a ref, the default branch or a branch's name through `gh api` | The `permissions.ask` entries in the owner's Claude Code settings (sgbett/dotfiles-claude `settings.json`): a permission prompt, present in a collaborator's session only if they add them |

The rulesets bind every account, admins included. The asks read command text, so combined short flags (`-fu`), abbreviated options, git aliases and config-driven forcing (`remote.<name>.push=+…`), `bash -c`, GraphQL sent from a file and `curl` with a token all pass without a prompt, as does deleting another author's work branch, which no ruleset covers either. An admin token can change a ruleset by any route, so the token's permissions are the real control.

To retire a project base or release branch, or to fix a mistagged release, an admin disables the ruleset, acts, and re-enables it at once, since nothing it covers is bound meanwhile. For the tag ruleset (the project-and-release one is the same with its template):

```sh
jq '.enforcement = "disabled"' ruleset-tags.json | gh api -X PUT repos/OWNER/REPO/rulesets/ID --input -
gh api -X PUT repos/OWNER/REPO/rulesets/ID --input ruleset-tags.json
```

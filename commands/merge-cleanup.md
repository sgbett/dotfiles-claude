# Merge Cleanup Command

Post-merge cleanup for branches after a PR has been merged. Renames the local branch with `merged/` prefix and deletes the remote branch.

## Usage

```
/merge-cleanup [branch-name]
```

If no branch name is provided, uses the current branch.

## Instructions

### 1. Determine the branch to clean up

If `$ARGUMENTS` contains a branch name, use that. Otherwise, get the current branch:
```bash
git branch --show-current
```

**IMPORTANT:** If the branch is `master`, STOP and report an error. Never clean up master.

### 2. Verify the branch exists locally

```bash
git branch --list <branch-name>
```

If not found, report error and stop.

### 3. Verify the PR was merged

Check if there's a merged PR for this branch:
```bash
gh pr list --head <branch-name> --state merged --json number,title
```

If no merged PR found, warn the user and ask for confirmation before proceeding.

### 4. Delete the remote branch (if it exists)

```bash
git push origin --delete <branch-name>
```

If the remote branch doesn't exist, that's fine - continue.

### 5. Rename the local branch

If currently on the branch being cleaned up, switch to master first:
```bash
git checkout master
```

Then rename:
```bash
git branch -m <branch-name> merged/<branch-name>
```

### 6. Report results

```
## Merge Cleanup Complete

Branch: <branch-name>
- Remote: Deleted from origin (or: Did not exist)
- Local: Renamed to merged/<branch-name>
```

## Safety Rules

- **NEVER** delete or rename `master`
- **NEVER** delete local branches outright - always rename to `merged/` prefix
- **NEVER** use `git branch -D` or `git branch -d` directly
- If in doubt, stop and ask the user

## Notes

- This command replaces manual post-merge cleanup steps
- The `merged/` prefix preserves branch history locally for reference
- Remote branches are deleted to keep the fork clean

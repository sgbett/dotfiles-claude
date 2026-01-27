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

**IMPORTANT:** If the branch is a "master" branch, STOP and report an error. Never clean up master.

A branch is considered "master" if it is:
- `master` (main repo master)
- `feature/#nnn_name/master` (worktree master pattern)

### 2. Determine the target "master" branch

For switching away from the branch being cleaned up, determine the correct master:

**Worktree pattern:** If the branch matches `feature/#nnn_name/something` (where `something` is NOT `master`):
- Extract the parent path: `feature/#nnn_name`
- Target master is: `feature/#nnn_name/master`

**Regular pattern:** Otherwise:
- Target master is: `master`

### 3. Verify the branch exists locally

```bash
git branch --list <branch-name>
```

If not found, report error and stop.

### 4. Verify the PR was merged

Check if there's a merged PR for this branch:
```bash
gh pr list --head <branch-name> --state merged --json number,title
```

If no merged PR found, warn the user and ask for confirmation before proceeding.

### 5. Delete the remote branch (if it exists)

```bash
git push origin --delete <branch-name>
```

If the remote branch doesn't exist, that's fine - continue.

### 6. Rename the local branch

If currently on the branch being cleaned up, switch to the target master first:
```bash
git checkout <target-master>
```

**Note:** Do NOT sync master with upstream - just switch to it. The user may have uncommitted work in other worktrees, and syncing can cause issues.

Then rename:
```bash
git branch -m <branch-name> merged/<branch-name>
```

### 7. Report results

```
## Merge Cleanup Complete

Branch: <branch-name>
- Remote: Deleted from origin (or: Did not exist)
- Local: Renamed to merged/<branch-name>
- Switched to: <target-master>
```

## Safety Rules

- **NEVER** delete or rename any "master" branch (`master` or `feature/#nnn_name/master`)
- **NEVER** delete local branches outright - always rename to `merged/` prefix
- **NEVER** use `git branch -D` or `git branch -d` directly
- **NEVER** sync/reset master during cleanup - just switch to it
- If in doubt, stop and ask the user

## Notes

- This command replaces manual post-merge cleanup steps
- The `merged/` prefix preserves branch history locally for reference
- Remote branches are deleted to keep the fork clean
- Worktree branches follow the pattern `feature/#nnn_name/sub-branch` with their own master at `feature/#nnn_name/master`

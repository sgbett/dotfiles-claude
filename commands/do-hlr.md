# Execute HLR (High-Level Requirement)

Implement all sub-tasks of a GitHub HLR issue sequentially, committing after each task.

**HLR Issue:** $ARGUMENTS

## Step 1: Fetch HLR and Sub-Issues

**Fetch the HLR issue details:**
```bash
gh issue view $ARGUMENTS
```

**Fetch all sub-issues linked to this HLR:**
```bash
gh api graphql -f query='
{
  repository(owner: "OWNER", name: "REPO") {
    issue(number: $ARGUMENTS) {
      title
      state
      subIssues(first: 50) {
        nodes {
          number
          title
          state
        }
      }
    }
  }
}'
```

Note: Replace OWNER and REPO with values from `gh repo view --json owner,name`.

## Step 2: Filter and Order Tasks

From the sub-issues list:
1. Filter to only OPEN issues (skip already closed/completed tasks)
2. Order by issue number (ascending) to respect creation order
3. Identify any dependency chains (tasks that block other tasks)

Create a work list:
```
Task Queue:
1. #24 - [Task 1] Create markdown generator utility
2. #25 - [Task 2] Generate person profile markdown files
3. #26 - [Task 3] Generate relationship profile markdown files
... etc
```

## Step 3: Pre-Flight Checks

Before starting:
1. Verify working tree is clean (`git status`)
2. Ensure on correct branch (create feature branch if needed)
3. Pull latest changes
4. Confirm no blockers on first task

If working tree is dirty:
- Ask user whether to stash, commit, or abort

## Step 4: Execute Task Loop

For each task in the queue:

### 4a. Start Task
```
═══════════════════════════════════════════════════════════
Starting Task #XX: [Task Title]
═══════════════════════════════════════════════════════════
```

### 4b. Execute Task
Invoke the /do:task skill for the current task number.

This will:
- Fetch task details
- Perform technical analysis
- Implement the solution
- Run tests
- Update task status

### 4c. Commit Changes
After task completion, commit all changes:

```bash
git add -A
git commit -m "feat: implement task #XX - [brief description]

Implements sub-task #XX of HLR #$ARGUMENTS.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### 4d. Verify and Continue
1. Confirm commit succeeded
2. Run any project tests to ensure no regressions
3. Update progress summary
4. Move to next task

```
═══════════════════════════════════════════════════════════
✓ Task #XX Complete - Committed as [commit-hash]
  Progress: 3/9 tasks complete
═══════════════════════════════════════════════════════════
```

## Step 5: Handle Failures

If a task fails:
1. **Do not proceed** to next task
2. Report the failure clearly
3. Preserve any partial work (don't discard)
4. Ask user how to proceed:
   - Retry the failed task
   - Skip and continue (mark task as blocked)
   - Abort HLR execution

## Step 6: Completion Summary

After all tasks complete (or execution stops):

```
═══════════════════════════════════════════════════════════
HLR #$ARGUMENTS Execution Summary
═══════════════════════════════════════════════════════════

HLR: [HLR Title]

Tasks Completed: 7/9
Tasks Skipped: 1 (already closed)
Tasks Failed: 1

Commits Created:
- abc1234 feat: implement task #24 - Create markdown generator
- def5678 feat: implement task #25 - Generate person profiles
- ghi9012 feat: implement task #26 - Generate relationship profiles
...

Failed Tasks:
- #30 - [Task 7] Generate decision support markdown
  Error: [error description]

Remaining Tasks:
- #31 - [Task 8] Create dashboard (blocked by #30)
- #32 - [Task 9] Validate wikilinks (blocked by #30)

Next Steps:
1. Review failed task #30 and resolve issues
2. Re-run /do:hlr $ARGUMENTS to continue from where we left off
═══════════════════════════════════════════════════════════
```

## Step 7: Close HLR (Optional)

If all tasks completed successfully:
1. Ask user if they want to close the HLR
2. If yes, close with summary comment:

```bash
gh issue close $ARGUMENTS --comment "All sub-tasks completed.

Commits:
- abc1234 task #24
- def5678 task #25
...

Implemented by Claude Code."
```

## Notes

- **Idempotent**: Safe to re-run - skips closed tasks automatically
- **Resumable**: If interrupted, re-run to continue from next open task
- **Commits per task**: Each task gets its own commit for clean history
- **No force push**: Never rewrites history or force pushes
- **Respects dependencies**: If a task has blockedBy issues that are open, skip it

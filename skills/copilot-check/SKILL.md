---
name: copilot-check
description: Check Copilot Review Comments. Fetches and analyses unresolved Copilot code review comments on the current PR. Use when user asks to "check copilot comments", "what did copilot say", "copilot review", or "/copilot-check".
allowed-tools: Bash,Read,Glob,Grep
---

# Check Copilot Review Comments

Fetch, analyse, and respond to Copilot code review comments on the current PR.

**Arguments:** `$ARGUMENTS` (optional PR number — if omitted, detect from current branch)

---

## Steps

### 1. Determine the PR

If a PR number was provided as `$ARGUMENTS`, use that. Otherwise detect from the current branch:

```bash
gh pr view --json number --jq '.number'
```

Get the repo owner/name:
```bash
gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"'
```

### 2. Fetch all review comments

Use the GitHub API to fetch review comments on the PR. Filter to Copilot-authored comments only.

```bash
# Fetch all review comments (these are inline code comments from reviews)
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments \
  --jq '.[] | select(.user.login == "copilot-pull-request-reviewer" or .user.login == "github-actions[bot]" or (.user.login | test("copilot";"i"))) | {id: .id, path: .path, line: .line, body: .body, created_at: .created_at}'
```

### 3. Check which comments are already resolved

A comment is "resolved" if it has a reply from a non-bot user. Fetch replies:

```bash
# For each comment, check if there are replies
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments \
  --jq '.[] | select(.in_reply_to_id) | {in_reply_to_id: .in_reply_to_id, user: .user.login, body: .body}'
```

Comments that have a non-bot reply are considered addressed (though not necessarily resolved in GitHub's UI).

### 4. Analyse each unresolved comment

For each unresolved Copilot comment:

1. Read the file and line it references (the file may have changed since the comment — check the current state)
2. Determine if the concern is:
   - **Already fixed** — the code has changed to address the concern
   - **Valid and actionable** — should be fixed in this PR
   - **Valid but out of scope** — legitimate concern but belongs in a separate issue
   - **Not applicable** — Copilot misunderstood the context (explain why)

### 5. Report

Present findings as a table:

| # | File:Line | Concern | Verdict | Action needed |
|---|-----------|---------|---------|---------------|
| 1 | path:123 | Brief summary | Fixed / Valid / Out of scope / N/A | What to do |

Group by verdict. For "valid and actionable" items, describe what needs to change.

**Then ask the user** whether to fix the actionable items and respond to all comments.

### 6. Fix actionable items

If the user approves, fix the valid and actionable items. Commit the fixes.

### 7. Reply to all comments

For each comment, reply using the PR review comment reply endpoint:

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments \
  -f body='Your reply text here' \
  -F in_reply_to={comment_id}
```

**Important API notes:**
- These are **pull request review comments** (inline code comments), NOT issue comments
- To reply, POST to `repos/{owner}/{repo}/pulls/{pr_number}/comments` with `in_reply_to` set to the parent comment ID
- Do NOT use `repos/{owner}/{repo}/pulls/comments/{id}/replies` — that endpoint does not exist
- Do NOT use `repos/{owner}/{repo}/issues/{pr_number}/comments` — those are issue-level comments, not review comments

**Reply categories** — use concise, factual replies:

- **Already fixed:** `"Fixed in {commit_sha} — {brief description of what changed}."`
- **Valid but out of scope:** `"Valid — {brief acknowledgement}. Tracked separately as {issue link or description}."`
- **Not applicable:** `"{Brief explanation of why the concern doesn't apply in this context}."`
- **Duplicate:** Reply to one instance with the substantive response. For duplicates, reply with `"See reply on {other_comment_description}."`

**Batch similar comments** — when multiple comments raise the same concern (Copilot often duplicates across review rounds), group them:

```bash
for id in {id1} {id2} {id3}; do
  gh api repos/{owner}/{repo}/pulls/{pr_number}/comments \
    -f body='Your reply' \
    -F in_reply_to=$id
done
```

### 8. Resolve review threads

After replying, resolve the review threads via the GraphQL API. First fetch the unresolved thread IDs:

```bash
gh api graphql -f query='
{
  repository(owner: "{owner}", name: "{repo}") {
    pullRequest(number: {pr_number}) {
      reviewThreads(first: 50) {
        nodes {
          id
          isResolved
          comments(first: 1) {
            nodes {
              author { login }
              body
            }
          }
        }
      }
    }
  }
}' --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false) | select(.comments.nodes[0].author.login == "copilot-pull-request-reviewer" or (.comments.nodes[0].author.login | test("copilot";"i"))) | .id'
```

Then resolve each thread:

```bash
for thread_id in {thread_ids}; do
  gh api graphql -f query="mutation { resolveReviewThread(input: { threadId: \"${thread_id}\" }) { thread { isResolved } } }"
done
```

Only resolve threads that were replied to in step 7. Do not resolve threads that were not addressed.

### 9. Summary

After replying and resolving, report what was done:

| Comment | Reply | Commit | Resolved |
|---------|-------|--------|----------|
| path:line — concern | What we said | sha (if fixed) | Yes/No |

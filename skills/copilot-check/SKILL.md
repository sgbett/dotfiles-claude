---
name: copilot-check
description: Check Copilot Review Comments. Fetches, adversarially verifies, and resolves Copilot code-review comments on the current PR, then drives an automated re-review loop (re-request → watch → verify → fix → converge). Use when the user asks to "check copilot comments", "what did copilot say", "copilot review", or "/copilot-check".
---

# Check Copilot Review Comments

Fetch, **verify**, act on, and resolve Copilot code-review comments — then keep the loop
running automatically until Copilot has nothing left to say.

**Arguments:** `$ARGUMENTS` (optional PR number — if omitted, detect from the current branch).

The old flow (fetch → report → ask → fix → reply → resolve → *stop*) required a human to
re-request Copilot and re-run the skill every round. This version:

- **Verifies before acting** — every finding is adversarially refuted first, so we never implement
  convincing nonsense.
- **Fixes the class, not the instance** — one agent per finding-class also scans for siblings.
- **Front-loads** — "be your own Copilot" before pushing, so Copilot re-reviews near-clean.
- **Closes the loop** — after pushing it re-requests Copilot (GraphQL), watches for the new review,
  and repeats to convergence; the only human touch is confirming sub-80%-confidence calls.

---

## Autonomy model (read first)

Per finding, after verification:

- **Refuted** (high-confidence nonsense — e.g. hits `## Do not flag`) → auto-reply + resolve, no fix.
- **Confirmed & fix-confidence ≥ 80%** → auto-fix.
- **Confirmed & fix-confidence < 80%, or verdict uncertain, or a big/tangential change** → **pause
  and flag for the human**; present a consolidated table and wait.

Loop control:

- A **round** = fetch → verify+scan → decide → act → push → re-request → watch.
- **While a human is engaged** (any round hit a pause the human answered) → keep iterating, no cap.
- **Fully autonomous rounds** (no human touch): after **10 consecutive** rounds without convergence,
  **stop and flag** "this is getting out of hand" (thrash — fixes not sticking).
- **Convergence** = a Copilot review round returns zero new confirmed-actionable findings → done.

**Nothing is silently deferred.** Every finding and every sibling instance is either fixed or
tracked (small → task issue; big → `[HLR]` + `project:hlr`). "Out of scope" alone is not an outcome.

---

## Phase 0 — Setup (once per PR)

1. **Determine the PR**, its base branch and whether it comes from a fork. If `$ARGUMENTS` is a bare number (`^[0-9]+$`), pass it as `{pr}`; if it is empty, omit it to detect from the branch; anything else (a PR URL included) → stop and ask, since owner/repo come from this checkout (step 2) and every later call must target the same repository. From here on `{pr}` is the returned `number`:
   ```bash
   gh pr view {pr} --json number,baseRefName,isCrossRepository
   ```
   **If `isCrossRepository` is true, stop and ask the user before continuing** — a fork's author isn't trusted, yet controls the code the verifiers read and the fixes would build on.
2. **Repo owner/name:**
   ```bash
   gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"'
   ```
3. **Load the rubric** from the base branch, never the working tree, into `{scratch}/rubric.md`. The branch name stays in a variable and goes by `-f`, which URL-encodes it; written into the path, a `+` or `#` in it would mangle the query. Only a 404 `Not Found` means there is none (an empty file); any other failure stops the run, since carrying on would silently drop the `## Do not flag` filter:
   ```bash
   base=$(gh pr view {pr} --json baseRefName --jq .baseRefName)
   gh api -X GET -H 'Accept: application/vnd.github.raw+json' \
     'repos/{owner}/{repo}/contents/.github/copilot-instructions.md' -f ref="$base" > {scratch}/rubric.md \
     || { jq -e '.message == "Not Found"' {scratch}/rubric.md >/dev/null && : > {scratch}/rubric.md; } \
     || { echo 'STOP: could not load the rubric' >&2; exit 1; }
   ```
   It is the reviewer's own rubric — use it three ways: (a) its `## Do not flag` section is a **false-positive filter** (a Copilot finding that contradicts it is almost certainly nonsense → refute); (b) its flag-lists are the **pattern checklist** for the sibling scan; (c) fixes must **conform** to it so we don't trip the reviewer on our own new code. Every use reads `{scratch}/rubric.md`, never the checkout's `.github/copilot-instructions.md`, which the PR itself can change.
4. **Record the high-water mark** — the latest Copilot review's `submittedAt`; the watcher fires on any review newer than this. **Default to the epoch when there is no prior review** (e.g. a bootstrap request), so the string comparison still holds — a `null` mark would make every real ISO timestamp compare *older* (digits sort before letters) and the watcher would never fire. The query sees the latest review however many there are (every `in_reply_to` reply adds a review, so a REST list's first page goes stale); `author:` only narrows by login and the jq id check is the match. A review under that login with any other id means Copilot's id has changed: the query errors (`error: STOP: …`) and the run stops, never falling back to the epoch:
   ```bash
   gh api graphql -f query='
   { repository(owner:"{owner}", name:"{repo}") { pullRequest(number:{pr}) {
       reviews(last:1, author:"copilot-pull-request-reviewer[bot]") { nodes {
         submittedAt author { ... on Bot { id } } comments { totalCount } } } } } }' \
     --jq '.data.repository.pullRequest.reviews.nodes[0] as $r
           | if $r == null then {submittedAt: "1970-01-01T00:00:00Z", comments: 0}
             elif $r.author.id == "BOT_kgDOCnlnWA" then {submittedAt: $r.submittedAt, comments: $r.comments.totalCount}
             else error("STOP: Copilot account id has changed — update the identity table") end'
   ```
   `submittedAt` is the mark; `comments` (the review's inline-comment count) feeds the 2a guard.

### Copilot's identity — match the account id, never the login

| Surface | API | Login | Type | Id |
|---|---|---|---|---|
| Review object | REST `pulls/{pr}/reviews` | `copilot-pull-request-reviewer[bot]` | `Bot` | `175728472` |
| Inline comment | REST `pulls/{pr}/comments` | `Copilot` | `Bot` | `175728472` |
| Requested reviewer | REST timeline `review_requested` | `Copilot` | `Bot` | `175728472` |
| Review / comment author | GraphQL `author` | `copilot-pull-request-reviewer` | `Bot` | `BOT_kgDOCnlnWA` |

One account, whose login differs by surface and is not its identity: the bare GraphQL login `copilot-pull-request-reviewer` is also held by an unrelated Organization (id 213165537). Every filter matches the id — REST `.user.id == 175728472` (`.requested_reviewer.id` on the timeline), GraphQL `author { ... on Bot { id } }` equal to `"BOT_kgDOCnlnWA"` — never a substring, regex or `contains`. An improvised query copies a row from this table.

**Us** is the viewer: GraphQL `viewerDidAuthor`; in REST, the login from `gh api user --jq .login`.

---

## Phase 1 — Front-load (first round only)

Before touching Copilot's comments, pre-empt the next round. Two cheap passes on the local diff:

1. **Semantic-ripple grep (always, deterministic).** For every change in the diff that widened/
   tightened/renamed a **regex, identifier, constant, or user-visible string**, `git grep -n` the
   old *and* related terms across the whole repo and fix every stale reference **in the same
   commit**. This is the single biggest iteration multiplier (often the majority of a review round)
   and it needs no agent.
2. **Turnkey `/code-review` (first round, if the diff is non-trivial).** Invoke the built-in
   review skill on the current diff **without `--fix`**:
   ```
   Skill(skill: "code-review", args: "high")
   ```
   It fields its own finder fleet, already self-scores and drops `<80`-confidence findings, and
   reads `CLAUDE.md` for project flavour. Take its findings as *input* and run them through the
   same Phase-3 gate (do **not** let it auto-apply) — its subjective (simplification/altitude)
   findings should pause for the human, not land silently.

---

## Phase 2 — Fetch, cluster, verify + scan

### 2a. Fetch the to-do Copilot threads

One GraphQL query returns every review thread with what the round needs. Save it to your scratchpad directory (`{scratch}`) so Copilot's text never reaches a command line. Stop if `gh` fails, even when it wrote `data` (a GraphQL error can come with partial data that would drop threads silently), or if there are more than 100 threads:

```bash
gh api graphql -f query='
{ repository(owner:"{owner}", name:"{repo}") { pullRequest(number:{pr}) {
    reviewThreads(first:100) { pageInfo { hasNextPage } nodes { id isResolved isOutdated
      first: comments(first:1) { nodes { databaseId path line originalLine originalCommit { oid } body
        author { __typename login ... on Bot { id } } } }
      last: comments(last:1) { nodes { viewerDidAuthor } } } } } } }' > {scratch}/threads.json \
  && jq -e '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage == false' {scratch}/threads.json >/dev/null \
  || { echo 'STOP: more than 100 review threads, or the query failed' >&2; exit 1; }
```

A thread is **to do** when it is unresolved, Copilot started it, and its last comment isn't ours — so a thread we've answered or someone resolved in GitHub's UI drops out, while a stranger's reply never counts as an answer:

```bash
jq '.data.repository.pullRequest.reviewThreads.nodes[]
    | select(.isResolved == false)
    | select(.first.nodes[0].author.id == "BOT_kgDOCnlnWA")   # Copilot started it
    | select(.last.nodes[0].viewerDidAuthor == false)          # last comment is not ours
    | {thread_id: .id, outdated: .isOutdated}
      + (.first.nodes[0] | {comment_id: .databaseId, path, line, original_line: .originalLine,
                            original_commit: .originalCommit.oid, body})' {scratch}/threads.json
```

`comment_id` (the first comment's `databaseId`) is the REST comment id that Phase 4's `in_reply_to` takes. An outdated thread's `line` is null once later commits move its code, so its location is `original_line` in `original_commit` (`git show {original_commit}:{path}`), from which the verifier finds that code in the head.

**Guard:** if the latest Copilot review (re-run the Phase 0 query) has `comments` above 0 but no thread in `{scratch}/threads.json` was started by Copilot, resolved or not (`jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.first.nodes[0].author.id == "BOT_kgDOCnlnWA")] | length'`), the filters no longer recognise Copilot: stop and flag it — never treat that as convergence. An empty to-do list with Copilot's threads all answered is convergence.

Cluster the to-do threads into **classes** (e.g. "stale reference after widening", "unrescued external call", "docstring ≠ behaviour").

### 2b. One combined verify+scan agent per class (parallel)

Spawn one `Task` agent per class, passing it each finding's fields from 2a and the text of `{scratch}/rubric.md` (or that there is none); verifiers never fetch PR comments or threads themselves, nor read the rubric from the checkout. Each does **both** jobs — they read the same code:

> **(a) Refute.** Given the real types / control-flow / call-sites and the rubric's `## Do not
> flag` list, does the concern actually hold? **Default to "refuted" when uncertain.**
> **(b) Scan.** If it holds, find *every other instance* of the pattern, seeded by the rubric's
> flag-lists. Split instances into in-scope (files the PR touches) vs related vs tangential.

Route **security-flavoured** classes (crypto, auth, memory-safety) to the **white-hat** agent for
(a). Cheap triage first: a finding that plainly hits `## Do not flag` is auto-refuted without
spending an agent.

**Structured return per class:**
```jsonc
{
  "class": "…",
  "verdict": "confirmed | refuted | uncertain",
  "verdict_confidence": 0.0,        // 0–1
  "hits_do_not_flag": false,        // true ⇒ strong auto-refute
  "evidence": "…",
  "original": { "path": "…", "line": 0 },
  "instances": [
    { "path": "…", "line": 0, "relation": "in-scope|related|tangential",
      "size": "minor|big", "disposition": "fix|task-issue|hlr" }
  ],
  "proposed_fix": "…",
  "fix_confidence": 0.0
}
```

Disposition bias (fix over defer, never drop): fix unless a change is **both tangential and big**;
otherwise track (small → task issue, big → `[HLR]`).

---

## Phase 3 — Decide (and maybe pause)

Sort each class + its confirmed instances by the autonomy model above:

- **Auto-queue:** refuted → reply+resolve; confirmed ≥80% → fix (incl. all fix-disposition siblings).
- **Human-pause queue:** confirmed <80%, uncertain, or big-tangential.

If the pause queue is non-empty, present a consolidated table and **wait**:

| # | File:Line | Class | Verdict (conf) | Other instances | Proposed action |
|---|-----------|-------|----------------|------------------|-----------------|

If empty, proceed autonomously (increment the unattended-round counter; halt at 10).

---

## Phase 4 — Act

1. **Fixes** — batched by class, conforming to the rubric (`{scratch}/rubric.md`). Apply the semantic-ripple
   grep again for any string/identifier the fixes themselves touch. Commit with a Conventional
   Commit referencing the PR.
2. **Tracking** — for tracked items, create the issue (task) or `[HLR]` + `project:hlr` (big); reference it in both the PR and the Copilot reply. Write the title and body to files in `{scratch}` first and pass them as below, never inline, since they quote Copilot's text:
   ```bash
   gh issue create --title "$(cat {scratch}/issue-title.txt)" --body-file {scratch}/issue-body.md   # HLR: add --label project:hlr
   ```
3. **Reply to every thread.** These are **pull-request review comments**, not issue comments — reply with `in_reply_to` set to 2a's `comment_id`. Write each body to a file in `{scratch}` first and post it with `-F body=@…`, since Copilot's text quoted back can contain quotes:
   ```bash
   gh api repos/{owner}/{repo}/pulls/{pr}/comments -F body=@{scratch}/reply.md -F in_reply_to={comment_id}
   ```
   - Do **not** use `pulls/comments/{id}/replies` (doesn't exist) or `issues/{pr}/comments` (wrong
     thread type).
   - Reply categories: `Fixed in {sha} — {what changed}.` · `Refuted — {why it doesn't apply}.` ·
     `Valid — tracked in #{n}.` · `Duplicate — see {other thread}.`
   - **Batch duplicates:** reply substantively once; on the rest, `See reply on {other}.`
     ```bash
     for id in {id1} {id2}; do gh api repos/{owner}/{repo}/pulls/{pr}/comments -F body=@{scratch}/see-other.md -F in_reply_to=$id; done
     ```
4. **Resolve replied threads.** Re-run the 2a fetch, its stop included, then select the unresolved, Copilot-started threads whose last comment is ours, and resolve each:
   ```bash
   jq -r '.data.repository.pullRequest.reviewThreads.nodes[]
          | select(.isResolved == false)
          | select(.first.nodes[0].author.id == "BOT_kgDOCnlnWA")   # Copilot started it
          | select(.last.nodes[0].viewerDidAuthor == true)           # last comment is ours
          | .id' {scratch}/threads.json
   ```
   ```bash
   for t in {thread_ids}; do
     gh api graphql -f query="mutation { resolveReviewThread(input:{threadId:\"$t\"}){ thread{ isResolved } } }"
   done
   ```
   The `last`-comment filter enforces this: a thread is resolved only when its most recent comment is **ours** — never one left un-addressed by a pause, nor one a stranger has replied to since.

---

## Phase 5 — Push, re-request, watch, loop

1. **Push** the branch.
2. **Re-request Copilot review — GraphQL, not REST.** REST `requested_reviewers` with `"Copilot"` silently no-ops (collaborator-only rule). Use `requestReviews` with Copilot's **bot node id**, the constant `BOT_kgDOCnlnWA` (the identity table's GraphQL row):
   ```bash
   gh api graphql -f query='{ repository(owner:"{owner}", name:"{repo}"){ pullRequest(number:{pr}){ id } } }' \
     --jq '.data.repository.pullRequest.id'
   #   → pr_id "PR_…"

   gh api graphql -f query='mutation { requestReviews(input:{
     pullRequestId:"PR_…", botIds:["BOT_kgDOCnlnWA"], union:true }){ pullRequest{ id } } }'
   ```
   `union:true` keeps existing reviewers. If this errors because a review is **already running**,
   assume one is underway and carry on to the watcher — don't treat it as a failure.
3. **Watch** for the new review (background bash; the harness re-invokes on exit). Copilot turnaround is ~3 min; watch the latest Copilot **review** (it lands atomically with its comments) with the Phase 0 query, not comments. Here its id check prints `ID_CHANGED` instead of raising an `error`, which `|| new=""` would take for a failed poll and retry until the timeout:
   ```bash
   hwm="{high_water_submitted_at}"
   deadline=$(( $(date +%s) + 15*60 ))
   until [ "$(date +%s)" -ge "$deadline" ]; do
     new=$(gh api graphql -f query='
       { repository(owner:"{owner}", name:"{repo}") { pullRequest(number:{pr}) {
           reviews(last:1, author:"copilot-pull-request-reviewer[bot]") { nodes {
             submittedAt author { ... on Bot { id } } } } } } }' \
       --jq ".data.repository.pullRequest.reviews.nodes[0] // empty
             | if .author.id == \"BOT_kgDOCnlnWA\" then select(.submittedAt > \"$hwm\") | .submittedAt
               else \"ID_CHANGED\" end") || new=""   # a failed poll is retried, never read as a review
     case "$new" in
       ID_CHANGED) echo "STOP: Copilot account id has changed — update the identity table"; exit 2 ;;
       [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*) echo "REVIEW_READY $new"; exit 0 ;;
     esac
     sleep 40
   done
   echo TIMEOUT; exit 1
   ```
   Run with `run_in_background: true`.
   - `REVIEW_READY` → set the high-water mark to the printed `submittedAt` and **loop back to Phase 2** (no front-load — that's first-round only).
   - `STOP: …` → a review under Copilot's login carries another id; stop and report it — don't converge or keep watching.
   - `TIMEOUT` → report "no re-review within 15 min" and stop. (The merge-gate ruleset means the
     human will notice a missing required review; Copilot occasionally no-ops.)
4. **Convergence / halt:** if a review round returns zero confirmed-actionable findings → **done**.
   If 10 unattended rounds pass without convergence → stop and flag.

---

## Phase 6 — Report

When converged (or halted/timed-out), summarise the whole run:

| Round | Findings | Confirmed | Refuted | Fixed | Tracked (issue/HLR) | Resolved |
|-------|----------|-----------|---------|-------|---------------------|----------|

Note rounds run, whether it converged, any items paused for the human, and any tracking issues/HLRs
opened. Stop any running watcher.

---

## Notes

- **British English** in replies, comments, commits.
- Prefer batching replies over per-comment round-trips; Copilot duplicates findings across rounds.
- The verify gate is load-bearing: a plausible suggestion that doesn't survive refutation gets a
  `Refuted` reply, never a fix.

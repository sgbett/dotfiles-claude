---
name: copilot-check
description: Check Copilot Review Comments. Fetches, adversarially verifies, and resolves Copilot code-review comments on the current PR, then drives an automated re-review loop (re-request → watch → verify → fix → converge). Use when the user asks to "check copilot comments", "what did copilot say", "copilot review", or "/copilot-check".
allowed-tools: Bash, Read, Glob, Grep, Edit, Write, Task, Skill
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

1. **Determine the PR.** If `$ARGUMENTS` is a PR number, use it; else detect from the branch:
   ```bash
   gh pr view --json number --jq '.number'
   ```
2. **Repo owner/name:**
   ```bash
   gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"'
   ```
3. **Load the rubric.** If `.github/copilot-instructions.md` exists, read it. It is the reviewer's
   own rubric — use it three ways: (a) its `## Do not flag` section is a **false-positive filter**
   (a Copilot finding that contradicts it is almost certainly nonsense → refute); (b) its flag-lists
   are the **pattern checklist** for the sibling scan; (c) fixes must **conform** to it so we don't
   trip the reviewer on our own new code.
4. **Record the high-water mark** — the latest Copilot review id + `submitted_at`, and the head SHA:
   ```bash
   gh api repos/{owner}/{repo}/pulls/{pr}/reviews \
     --jq '[.[] | select(.user.login=="copilot-pull-request-reviewer[bot]")] | last | {id, submitted_at}'
   ```

### Copilot has three identities — handle all of them

| Surface | API | `login` |
|---|---|---|
| Review object | `pulls/{pr}/reviews` | `copilot-pull-request-reviewer[bot]` |
| Inline comment | `pulls/{pr}/comments` | `Copilot` |
| Requested reviewer | timeline `review_requested` | `Copilot` |

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

### 2a. Fetch unresolved Copilot comments

```bash
gh api repos/{owner}/{repo}/pulls/{pr}/comments --paginate \
  --jq '.[] | select((.user.login|test("copilot";"i")) and (.in_reply_to_id|not))
             | {id, path, line, body, created_at}'
```

Drop threads already addressed — a Copilot thread with a non-bot reply, or resolved in GitHub's UI
(check via the GraphQL `reviewThreads` query in Phase 4). Cluster the rest into **classes** (e.g.
"stale reference after widening", "unrescued external call", "docstring ≠ behaviour").

### 2b. One combined verify+scan agent per class (parallel)

Spawn one `Task` agent per class. Each does **both** jobs — they read the same code:

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

1. **Fixes** — batched by class, conforming to `copilot-instructions.md`. Apply the semantic-ripple
   grep again for any string/identifier the fixes themselves touch. Commit with a Conventional
   Commit referencing the PR.
2. **Tracking** — for tracked items, create the issue (task) or `[HLR]` + `project:hlr` (big);
   reference it in both the PR and the Copilot reply.
3. **Reply to every thread.** These are **pull-request review comments**, not issue comments — reply
   with `in_reply_to`:
   ```bash
   gh api repos/{owner}/{repo}/pulls/{pr}/comments -f body='…' -F in_reply_to={comment_id}
   ```
   - Do **not** use `pulls/comments/{id}/replies` (doesn't exist) or `issues/{pr}/comments` (wrong
     thread type).
   - Reply categories: `Fixed in {sha} — {what changed}.` · `Refuted — {why it doesn't apply}.` ·
     `Valid — tracked in #{n}.` · `Duplicate — see {other thread}.`
   - **Batch duplicates:** reply substantively once; on the rest, `See reply on {other}.`
     ```bash
     for id in {id1} {id2}; do gh api repos/{owner}/{repo}/pulls/{pr}/comments -f body='…' -F in_reply_to=$id; done
     ```
4. **Resolve replied threads.** Fetch unresolved Copilot thread ids, then resolve each:
   ```bash
   gh api graphql -f query='
   { repository(owner:"{owner}", name:"{repo}") { pullRequest(number:{pr}) {
       reviewThreads(first:50){ nodes{ id isResolved comments(first:1){ nodes{ author{login} } } } } } } }' \
     --jq '.data.repository.pullRequest.reviewThreads.nodes[]
           | select(.isResolved==false)
           | select(.comments.nodes[0].author.login|test("copilot";"i")) | .id'
   ```
   ```bash
   for t in {thread_ids}; do
     gh api graphql -f query="mutation { resolveReviewThread(input:{threadId:\"$t\"}){ thread{ isResolved } } }"
   done
   ```
   Only resolve threads that were actually replied to.

---

## Phase 5 — Push, re-request, watch, loop

1. **Push** the branch.
2. **Re-request Copilot review — GraphQL, not REST.** REST `requested_reviewers` with `"Copilot"`
   silently no-ops (collaborator-only rule). Use `requestReviews` with the Copilot **bot node id**,
   which is derivable from the prior review author (always present here — we're responding to a
   Copilot review):
   ```bash
   # PR node id + Copilot bot node id
   gh api graphql -f query='{ repository(owner:"{owner}", name:"{repo}"){ pullRequest(number:{pr}){
     id reviews(last:10){ nodes{ author{ __typename login ... on Bot{ id } } } } } } }'
   #   → pr_id "PR_…";  bot id "BOT_…"  (globally stable fallback: BOT_kgDOCnlnWA)

   gh api graphql -f query='mutation { requestReviews(input:{
     pullRequestId:"PR_…", botIds:["BOT_…"], union:true }){ pullRequest{ id } } }'
   ```
   `union:true` keeps existing reviewers. If this errors because a review is **already running**,
   assume one is underway and carry on to the watcher — don't treat it as a failure.
3. **Watch** for the new review (background bash; the harness re-invokes on exit). Copilot turnaround
   is ~3 min; watch the atomic **reviews** endpoint, not comments:
   ```bash
   repo={owner}/{repo}; pr={pr}; hwm="{high_water_submitted_at}"
   deadline=$(( $(date +%s) + 15*60 ))
   until [ "$(date +%s)" -ge "$deadline" ]; do
     n=$(gh api repos/$repo/pulls/$pr/reviews \
       --jq "[.[] | select(.user.login==\"copilot-pull-request-reviewer[bot]\")
                   | select(.submitted_at > \"$hwm\")] | length")
     [ "$n" -gt 0 ] 2>/dev/null && { echo REVIEW_READY; exit 0; }
     sleep 40
   done
   echo TIMEOUT; exit 1
   ```
   Run with `run_in_background: true`.
   - `REVIEW_READY` → update the high-water mark and **loop back to Phase 2** (no front-load — that's
     first-round only).
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

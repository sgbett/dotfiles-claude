# Plan: Automate & harden `/copilot-check` (+ front-load & reviewer memory)

**Date:** 2026-07-04
**Status:** Draft — awaiting approval to implement
**Tracking:** [sgbett/dotfiles-claude#2](https://github.com/sgbett/dotfiles-claude/issues/2)
**Target:** `~/.claude/skills/copilot-check/SKILL.md` (global skill, benefits all projects),
plus a front-load step and a two-layer pattern corpus (see §12).

> §1–11 are the validated, contained core (the loop automation). §12 is an additive layer from a
> sister session (secp256k1 #55) that expands scope to front-loading and reviewer memory — phased
> and deliberately guarded against over-engineering.

---

## 1. Problem

The current `/copilot-check` flow (fetch → analyse → report → ask → fix → reply → resolve) is
correct but laborious. It iterates many times per PR because of four independent multipliers:

1. **Single-instance fixes** — we fix the one line Copilot flagged; the same *class* survives
   elsewhere and gets re-flagged next round.
2. **Convincing nonsense** — we implement a plausible-but-wrong suggestion, which then gets
   re-flagged or spawns a *new* finding.
3. **Manual re-trigger + manual re-fetch** — dead time and human attention between every round.
4. **Self-inflicted findings** — our *fixes* introduce new code Copilot then flags. Largely
   preventable by conforming fixes to the repo's reviewer rubric before pushing.

## 2. Goals

- **G1** Reduce round count by fixing *classes* not *instances*, and by refusing to implement
  bogus suggestions.
- **G2** After pushing fixes, automatically re-request Copilot review and watch for the result —
  no manual re-trigger, no manual re-fetch.
- **G3** Rigorously verify every Copilot suggestion before acting (reject convincing nonsense).
- **G4** Never silently defer a real issue ("out of scope" is bit-rot) — fix it or track it.

---

## 3. Probe findings (validated 2026-07-04)

Read-only probe across `sgbett/bsv-ruby-sdk` (#912), `sgbett/secp256k1-native` (#55),
`sgbett/bsv-wallet`. These facts ground the whole design:

### 3.1 Copilot's three identities — the skill must handle all three

| Surface | API | `login` |
|---|---|---|
| Review object | `GET /repos/{o}/{r}/pulls/{pr}/reviews` | `copilot-pull-request-reviewer[bot]` (GraphQL `Bot`, login `copilot-pull-request-reviewer`) |
| Inline review comment | `GET /repos/{o}/{r}/pulls/{pr}/comments` | `Copilot` |
| Requested reviewer | timeline `review_requested` | `Copilot` |

The current skill filters comments with a case-insensitive `test("copilot";"i")` which *does*
catch `Copilot` — but the exact strings above should be used explicitly for robustness.

### 3.2 Copilot does NOT reliably auto-review on push — premise confirmed

On secp256k1 #55, **every** Copilot review lands **2.5–3.5 min after an explicit
`review_requested` event**. Pushes at `07-03T22:02`, `07-04T01:57`, `07-04T08:40` triggered
**no** review; only explicit re-requests did.

The repo ruleset ("Copilot review for default branch" / "Copilot Review") makes a Copilot review a
**merge gate**. It also exposes *Settings → Rulesets → Branch Rules → ✅ Automatically request
Copilot code review → Show Additional Settings → ✅ **Review new pushes***, which *should* re-review
every push — but empirically it fires only occasionally and unpredictably (no discernible pattern to
which pushes trigger). **Design assumption: treat auto-on-push as "won't fire" and re-request
ourselves.** Simon has been re-requesting by hand each round — the laborious step, and fixable.

### 3.3 Re-request mechanism — GraphQL, not REST (validated live 2026-07-04)

REST is a dead end; GraphQL works:

- **REST `POST /pulls/{pr}/requested_reviewers` with `reviewers:["Copilot"]` silently no-ops** —
  returns 200 but registers nothing (GitHub's collaborator-only rule drops the bot). No error to
  catch; it just does nothing. Do **not** use it.
- **GraphQL `requestReviews` with the Copilot bot node id works:**

```bash
# 1. Get PR node id + Copilot bot node id. In /copilot-check we ALWAYS have a prior Copilot
#    review (we're responding to its comments), so derive the bot id from the review author:
gh api graphql -f query='{ repository(owner:"O", name:"R"){ pullRequest(number:N){
  id reviews(last:10){ nodes{ author{ __typename login ... on Bot{ id } } } } } } }'
#    → pr_id e.g. "PR_kwDOSMswA87s7dww";  bot id e.g. "BOT_kgDOCnlnWA"
#      (bot id appears globally stable — usable as a fallback if no prior review exists)

# 2. Request the review:
gh api graphql -f query='mutation { requestReviews(input:{
  pullRequestId:"PR_...", botIds:["BOT_kgDOCnlnWA"], union:true }){
  pullRequest{ reviewRequests(first:5){ nodes{ requestedReviewer{ __typename ... on Bot{login} } } } } } }'
#    → confirmed: reviewRequests now contains {Bot, copilot-pull-request-reviewer}
```

- **`union:true`** adds Copilot without clobbering existing requested reviewers.
- **If a review is already in flight**, the re-request may error → **assume a review is underway and
  carry on** (proceed to the watcher); do not treat it as a failure.
- After Copilot reviews it removes itself from requested reviewers (§3.4).

### 3.4 Timing & completion signal

- Turnaround ≈ **3 min** (request → review). Watcher: poll every **30–45 s**, timeout **~12–15 min**.
- **Watch the `reviews` endpoint, not `comments`.** A review is atomic — when a new review object
  with `user.login == copilot-pull-request-reviewer[bot]` and `submitted_at > request_time`
  appears, all its inline comments are guaranteed present. Polling comments races partial arrival.
- Copilot **removes itself** from `requested_reviewers` after reviewing (endpoint reads empty).

### 3.5 `.github/copilot-instructions.md` is a structured rubric — two free levers

Present in all probed repos (83–94 lines). Structured into `## Conventions`, per-area
**flag** lists, and a **`## Do not flag`** section. Two direct uses:

- **`## Do not flag` = false-positive filter (G3).** If Copilot flags something the instructions
  say not to flag (e.g. single-letter curve params, `mul_vt` variable-time ops), we can
  **auto-refute** it with high confidence.
- **Flag-lists = pattern checklist (G1).** The proactive scan seeds its search from these
  categories ("carry propagation", "modulus confusion", "constant-time secret paths"), so it
  hunts the *same* patterns Copilot hunts — finding siblings before the next round does.

---

## 4. Design decisions (agreed)

**D1 — Scope: fix over defer, never drop.** Every similar instance found is surfaced at minimum.
Disposition bias:

| | Minor | Big |
|---|---|---|
| **Related to PR** | Fix (this PR) | Fix (this PR; big → flag for human, may stack a follow-up PR) |
| **Tangential** | Fix (this PR) | **Track**, don't fix |

- Not fixing ⇒ **track**: small ⇒ tightly-scoped **task issue**; big ⇒ new **HLR** (`[HLR] `,
  `project:hlr`). Tracking issues also flag the area as "worth a closer look".
- Nothing is silently deferred. The report lists every instance and its disposition.
- Scope-expansion caveat: fixing tangential code enlarges the diff Copilot reviews next round
  (more surface → potentially more findings). The 80/20 confidence gate (D2) naturally throttles
  this — tangential fixes tend to score <80% and route to a human pause.

**D2 — Autonomy: 80/20 with a human throttle.** Per finding:

- **Refuted** (high-confidence nonsense, e.g. hits `## Do not flag`) → auto-reply + resolve, no fix.
- **Confirmed & fix confidence ≥ 80%** → auto-fix.
- **Confirmed & fix confidence < 80%, or verdict uncertain** → **pause & flag** for human.

Loop control:

- A **round** = fetch → verify+scan → decide → fix/reply/resolve → push → re-request → watch.
- **While a human is engaged** (any round hit a pause the human answered) → keep iterating, no cap.
  The human is the throttle.
- **Fully autonomous rounds** (no human touch): if **10 consecutive** rounds pass without reaching
  convergence → **pause & flag** "this is getting out of hand". (Convergence should be fast; 10
  auto-rounds of churn signals thrash — e.g. fixes not sticking, or a fix/flag oscillation.)
- **Convergence** = a Copilot review round returns zero new confirmed-actionable findings → done;
  report; stop watcher.

**D3 — Conform fixes to the rubric.** Load `copilot-instructions.md` before writing any fix and
make fixes obey it, to avoid self-inflicted findings (multiplier #4).

---

## 5. Redesigned workflow

```
Phase 0  SETUP (once per PR)
  - Resolve PR/repo (existing logic).
  - Load .github/copilot-instructions.md (if present) → rubric for verify + scan + fix.
  - Record high-water mark: latest Copilot review id + submitted_at, and head SHA.

Phase 1  FETCH & CLUSTER
  - Fetch Copilot review comments (handle all three identity spellings, §3.1).
  - Drop already-addressed threads (existing reply/resolve logic).
  - Cluster remaining findings into *classes* (e.g. "missing nil guard", "carry not propagated").

Phase 2  VERIFY + SCAN  — one combined agent per class, in PARALLEL
  For each class, spawn one agent that does BOTH jobs (they look at the same code):
    (a) REFUTE the finding using real types/control-flow/call-sites and the rubric's
        `## Do not flag` list. Default to "refuted" when uncertain.
    (b) If it holds, find EVERY other instance of the pattern, seeded by the rubric's flag-lists.
  Returns structured output (§6.2): verdict, confidence, evidence, instances[in-scope|tangential],
  proposed fix + fix-confidence, suggested disposition (fix | task-issue | HLR).

Phase 3  DECIDE & (maybe) PAUSE
  - Refuted → queue auto-reply + resolve.
  - Confirmed & fix-confidence ≥80% → queue auto-fix (incl. all fix-disposition siblings).
  - Confirmed <80% / uncertain / big-tangential → collect into a HUMAN-PAUSE report.
  - If pause queue non-empty → present consolidated table, ask once, wait. (resets auto-counter)
  - If pause queue empty → proceed autonomously (increment auto-round counter; halt-check at 10).

Phase 4  ACT
  - Apply fixes (batched, conform to rubric); create task-issues / HLRs for tracked items.
  - Reply to every thread (existing categories + "Refuted: <why>" + "Tracked in #N").
  - Resolve replied threads (existing GraphQL logic).

Phase 5  PUSH · RE-REQUEST · WATCH
  - Commit + push.
  - Re-request Copilot review (§3.3).
  - Launch background watcher (§6.1): poll reviews endpoint until a new bot review appears
    (submitted_at > push time) or timeout. On hit → re-invoke skill from Phase 1.
  - Loop until convergence (§4 D2) or a halt condition.

Phase 6  DONE
  - Report: rounds run, findings confirmed/refuted, fixes applied, issues/HLRs opened, threads
    resolved. Stop watcher.
```

Only human touchpoint: Phase 3 pauses (sub-80% or big-tangential). Everything else is automated.

---

## 6. Component detail

### 6.1 The watcher (background bash, event-driven)

```bash
# Args: repo, pr, since_iso (push time). Poll reviews; exit 0 when a NEW bot review lands.
deadline=$(( $(date +%s) + 15*60 ))
until [ "$(date +%s)" -ge "$deadline" ]; do
  new=$(gh api repos/$repo/pulls/$pr/reviews \
    --jq "[.[] | select(.user.login==\"copilot-pull-request-reviewer[bot]\")
                | select(.submitted_at > \"$since_iso\")] | length")
  [ "$new" -gt 0 ] && { echo "REVIEW_READY"; exit 0; }
  sleep 40
done
echo "TIMEOUT"; exit 1
```

Run with `run_in_background: true`; the harness re-invokes on exit. `REVIEW_READY` → continue from
Phase 1; `TIMEOUT` → report "no re-review after 15 min" and stop (Copilot occasionally no-ops; the
merge gate ruleset means the human will notice the missing required review anyway).

> Note on `date`: the workflow/skill runs as normal shell (not the Workflow JS sandbox), so
> `date +%s` is fine here.

### 6.2 Combined verify+scan agent — structured output schema

```jsonc
{
  "class": "carry not propagated through all four limbs",
  "verdict": "confirmed | refuted | uncertain",
  "verdict_confidence": 0.0,          // 0–1
  "evidence": "field.c fred() second pass drops FRED_C high-word carry; ...",
  "hits_do_not_flag": false,          // true ⇒ strong auto-refute signal
  "original": { "path": "...", "line": 0 },
  "instances": [
    { "path": "...", "line": 0, "relation": "in-scope|related|tangential",
      "size": "minor|big", "disposition": "fix|task-issue|hlr" }
  ],
  "proposed_fix": "…",
  "fix_confidence": 0.0
}
```

Agent type: default `claude` / `general-purpose`. For security-flavoured findings (crypto, auth,
memory safety) route the verify step to **white-hat**. Cheap triage first: findings that clearly
hit `## Do not flag` are auto-refuted without spending a full agent.

### 6.3 Fixes, replies, issues

- Fixes conform to `copilot-instructions.md` (D3); batched by class.
- Reply categories (extend current set): `Fixed in {sha}`, `Refuted: {why}` (new),
  `Tracked in #{n}` (new), `Valid — out of scope, tracked in #{n}`, `Duplicate — see {ref}`.
- Tracking: task-issue (small) or `[HLR]` + `project:hlr` (big), per global CLAUDE.md HLR rules.
  Reference the new issue in both the PR and the Copilot reply.

---

## 7. Skill structural changes

- **`allowed-tools`** — the skill needs bash, file edits, agent spawning, and skill invocation
  (`/code-review` for Phase B). Rather than an explicit list (the `Skill`/`Task` token names aren't
  reliably supported in `allowed-tools`), **omit the key entirely** and run unrestricted — matching
  `do-hlr`, the sibling skill that also invokes `Skill()`/agents. (Resolved via Copilot review on #3.)
- Skill stays a **markdown skill executed turn-by-turn** (not a `Workflow`). Rationale: the
  human-pause model fits the turn loop; Workflow runs detached and can't cleanly pause for input.
  The Phase-2 fan-out uses the `Task`/Agent tool. (A `Workflow` could later accelerate the
  fully-autonomous verify+scan fan-out, but is not the primary design.)
- Keep all existing REST/GraphQL reply + resolve logic (it is correct and well-documented).

---

## 8. How each goal is met

| Goal | Mechanism |
|---|---|
| G1 fewer rounds | class-level fix + proactive sibling scan (Phase 2) + refute-nonsense + rubric-conforming fixes |
| G2 auto re-review | re-request `Copilot` (§3.3) + background watcher on reviews endpoint (§6.1) |
| G3 verify suggestions | adversarial refute + `## Do not flag` filter (Phase 2 / §6.2) |
| G4 no bit-rot | fix-or-track disposition, nothing dropped (D1) |

---

## 9. Risks & guardrails

- **Re-request must use GraphQL `requestReviews` with the bot node id** — REST silently no-ops
  (§3.3). Derive bot id from prior review author; fall back to `BOT_kgDOCnlnWA`.
- **Re-request while a review is running** may error → assume underway, carry on to watcher (§3.3).
- **"Review new pushes" ruleset setting fires unreliably** → never depend on it; always re-request.
- **Runaway loop / cost** → 10 auto-round halt; human pause resets; convergence check each round.
- **Scope creep from tangential fixes** → 80/20 gate routes them to human; big-tangential is tracked
  not fixed.
- **Watcher hangs / Copilot no-ops** → 15-min timeout, graceful report.
- **Partial review race** → mitigated by watching atomic review objects, not comments.
- **Agent over-eager refute or over-eager confirm** → confidence thresholds + white-hat routing for
  security; refutes still get a posted reply so the human sees the reasoning on the thread.

## 10. Live validation — DONE (2026-07-04, secp256k1 #55)

Confirmed on the live PR: REST no-ops silently; GraphQL `requestReviews` (§3.3) registers the
request and Copilot begins reviewing (~3 min turnaround). Watcher on the `reviews` endpoint detects
the new bot review. Mechanism is settled — no further pre-build validation needed.

## 11. Build order (once approved)

1. ~~Live-confirm re-request~~ — done (§10).
2. Rewrite `SKILL.md`: Phase 0–1 (identities, rubric load, cluster).
3. Add Phase 2 combined verify+scan agent + schema.
4. Add Phase 3 autonomy/pause logic + Phase 4 act (fixes, replies, tracking issues).
5. Add Phase 5 re-request + watcher + loop/convergence/halt.
6. Dry-run end-to-end on one live PR (e.g. bsv-ruby-sdk #912 or secp256k1 #55) with the human
   gate forced on for the first pass; then let it auto-loop once.
7. Roll out; note in any per-repo docs that a `.github/copilot-instructions.md` sharpens both the
   scan and the false-positive filter.

---

## 12. Expanded scope — front-loading & reviewer memory (from secp256k1 session)

A sister session attacked the same pain from the "get ahead of Copilot" side. It surfaced three
additions. They are **separable concerns** (SRP) and should be **phased**, not built at once.

### 12.1 The reframe

The core loop (§1–11) makes *reacting* to Copilot cheap. Front-loading makes Copilot *find less*.
Reviewer memory makes both *smarter over time*. Key evidence from the session:

- On one PR, **5 of 10** Copilot findings were a single class — *consistency drift after a widening
  change* (one regex widened `uint64_t`→`uint32_t|uint64_t`; 5 stale references remained; only 1–2
  fixed per round, so Copilot re-flagged the rest for two more rounds). **This one class is
  deterministically grep-able** and is the single biggest iteration multiplier.
- An A/B: `/code-review high` on a PR everyone (incl. Copilot) thought done spun **7 finder agents**
  and produced **10 findings** — Copilot had found **zero**. So `/code-review` covers a *different,
  complementary* set (reuse / simplification / efficiency / altitude / removed-behaviour) that is a
  Copilot **blind spot**, not just a pre-emption of Copilot's niche.

### 12.2 Empirical taxonomy (seed data for classification + corpus)

Copilot's demonstrated core competencies, and the finding classes observed:

| Class | Copilot competency | Grep-able? |
|---|---|---|
| Consistency drift after widening/rename | cross-file consistency (reads every string in diff) | **Yes** (ripple grep) |
| Error-path completeness (`\|\| true`, unrescued extern calls, silent `ENV` fallback) | error-path analysis | partly |
| Docstring / comment ≠ behaviour | comment-vs-code drift | partly |
| Unused / redundant config | — | partly |
| Real bug from initial cut | general | no (needs agent) |

This table is the starter content for the cross-project corpus (§12.5) and the classification
labels the loop assigns to each finding.

### 12.3 Semantic-ripple grep — first-class, deterministic, cheap (highest leverage)

Before **every** push (and before opening the PR), for each fix that changes a **regex, identifier,
constant, or user-visible string**: `git grep -n` the old *and* related terms across the whole repo;
fix every stale hit in the **same commit**. Deterministic, no agent, catches the #1 multiplier.
Would have collapsed 2 rounds → 0 on the example PR. **Add as a pre-push phase (Phase 5a).**

### 12.4 Front-loading: "be your own Copilot" before push

Run a Copilot-shaped review of the local diff *before* pushing, so Copilot re-reviews near-clean.

- **Engine: leverage `/code-review`, don't rebuild it.** It has its own built-in finder fleet
  (7 at `high`: line-by-line, removed-behaviour, cross-file, reuse, simplification, efficiency,
  altitude) and effort tiers. **It accepts no custom agents and no config file** — its only
  auto-ingested "config" is `CLAUDE.md` (root + modified dirs); inputs are effort + `--comment`/
  `--fix`. So we call it **turnkey** (it carries project flavour via `CLAUDE.md` for free). The
  corpus (§12.5) does **not** feed `/code-review`; it feeds our own agents (§12.5).
- **It already self-verifies.** `/code-review` scores each finding 0–100 and drops `<80` — the same
  threshold as our gate (§4 D2). So its output is pre-filtered high-confidence; don't double-score.
- **Invoke without `--fix`.** Take its findings and run them through our single Phase-3 gate so
  subjective (simplification/altitude) findings can pause for the human, rather than auto-applying.
- **Naming note:** the official plugin also ships a simpler `/code-review` *command*; the built-in
  *skill* (7 finders, effort tiers, `--fix`) is the one to invoke.
- **Right-size the cost** (answering "is 7 agents worth it?"): run **`/code-review high` once
  before PR open** (worth it — it found 10 real issues Copilot never would); inside the loop use a
  **light pre-push pass** (semantic-ripple grep always; a medium/targeted review only if the round
  changed non-trivial logic). Not 7 agents every round.
- **Front-loaded findings go through the same 80/20 verify gate** (§4 D2). `/code-review`'s
  subjective findings (simplification/altitude) are more likely to route to a human pause — this is
  correct, and prevents self-inflicted churn from acting on opinions.
- **Placement:** a pre-push sub-step of the loop's push phase (front-loads every round), plus the
  existing option to run `/code-review high` manually pre-PR. Don't over-couple the two skills.

### 12.5 Reviewer memory — the pattern corpus (phase in as a DUMB file first)

**Vision** (the "gem"): a corpus that accumulates the kinds of things worth looking for, carrying
Simon+Claude's design *flavour* and — crucially — its **shadow**: every explicit principle set (e.g.
a project CLAUDE.md's stated principles) creates an aperture; what falls outside is invisibly
deprioritised (contributor ergonomics, consumer-doc clarity, test-loop friction, portability,
error-message quality). A corpus that only encodes the stated principles inherits their exact bias.

**Two layers, one lookup path:**

```
~/.claude/review-patterns/          # cross-project, universal (seed from §12.2 taxonomy)
  consistency-drift.md
  error-path-completeness.md
  docstring-behaviour-drift.md
  ...
<project>/.claude/review-patterns/  # per-project overlay
  <stated-principle patterns>
  shadow/<what the stated principles miss>
```

**Feedback loop (target):** finding → add/update pattern md → next PR's front-load reads the corpus
as a checklist → findings classified against patterns → measure which fire / are dormant / need
refining. `/copilot-check` is the data pipe: each classified Copilot finding is a data point;
patterns that recur on a repo get promoted into its overlay. Auto-memory (`~/.claude/.../memory/`)
is a source — preference-shaped patterns (`[[feedback_prefer_removing_code]]` etc.) link to memories.

**Complexity guard — start minimal:**
- **v1 = one flat, appendable markdown checklist per layer.** Read as context by the front-load
  review; append a line when a pattern recurs. No classification engine, no auto-promotion, no
  dashboards. Seed the cross-project layer from the §12.2 table.
- **Earn the machinery:** only add classification / auto-promotion / dormancy-tracking / dashboards
  *after* the flat file demonstrably reduces findings. Measure first (see caveat).
- **Precision caveat (verify-don't-affirm):** a checklist read by review agents *amplifies false
  positives* — the reviewer finds what it's told to look for. The A/B's 10-findings-on-a-done-PR is
  already a signal of aggressive-review noise. So: phrase patterns as **questions** ("does any
  string still say X?") not commands ("flag X"); keep every corpus-driven finding behind the
  adversarial verify gate; and track **precision** (share of corpus-driven findings that survive
  verification). If precision drops, prune the corpus — it is not append-only forever.
- **Reviewer agents:** deferred. `/code-review`'s existing finders + corpus-as-context deliver the
  "several focused reviewers" idea without bespoke agents. Reconsider only if a project needs a lens
  `/code-review` structurally lacks.

### 12.6 Phasing (recommendation — keeps complexity bounded)

| Phase | Scope | State |
|---|---|---|
| **A** | Loop automation (§1–11): re-request, watch, verify+scan, 80/20, converge | validated — build first |
| **B** | Semantic-ripple grep (§12.3) + right-sized front-load via `/code-review` (§12.4) | cheap, high-leverage — build next |
| **C** | Corpus v1: flat two-layer checklist seeded from §12.2, read + append (§12.5) | build minimal; **no** learning machinery yet |
| **D** | Learning machinery (classification, auto-promotion, dormancy, dashboards, bespoke reviewer agents) | **deferred** until C proves out on real data |

Rationale: A is independently valuable and ready. B is low-complexity, high-return. C is where the
vision starts but as a flat file it's near-free and reversible. D is the speculative cathedral —
gate it behind measured evidence that C helps. This is YAGNI on the learning system while keeping
the structural seams (SRP) so D can slot in later without rework.

### 12.7 Open decisions for §12

1. **Phasing** — RESOLVED: A → B → C, defer D. (agreed 2026-07-04)
2. **`/code-review` capabilities** — RESOLVED: own agents, no custom-agent/config injection, auto-
   reads `CLAUDE.md`, self-filters `<80`. ⇒ (B) calls it turnkey; the corpus (C) feeds
   `/copilot-check`'s own agents, not `/code-review`. Old "decision 4" (teach `/code-review` the
   corpus) is dropped.
3. **Corpus scope for v1** — cross-project only, per-project only, or both layers from the start?
   (Recommend both layers but each a single flat file; per-project seeded from that repo's history.)
4. **Front-load placement** — in-loop pre-push only, or also a standalone pre-PR `/code-review high`
   habit/hook? (Recommend both, uncoupled.)

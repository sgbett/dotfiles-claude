# Plan: Config housekeeping

**Date:** 2026-10-14
**Status:** Agreed 14 Oct; refined 16 Oct — #7-bundle gap resolved, `/do` adopted as a parallel-build + cutover (D7/D8), all other work paused while underway. First cut and specialist panel folded in (§7, D9–D11). Prerequisite (step 0) done; W0 (building `/do`) under way.
**Tracking:** [sgbett/dotfiles-claude#9](https://github.com/sgbett/dotfiles-claude/issues/9)
**Sibling:** [#7 Config profiles](https://github.com/sgbett/dotfiles-claude/issues/7) delivered the `profiles/` `@import` mechanism and the first bundle (`git-workflow.md`), then closed. The shareable work-organisation bundle itself is created here (Step 7) on that mechanism.

---

## 1. Why

The config should support one way of working and get out of its way:

- **Lead maintainer across many projects.** Work is organised and tracked so it's possible to move between projects and see what's done, in progress (and how far along) and still to do.
- **Less is more.** Early configs were too prescriptive and grew brittle as models improved.
- **`/do-hlr` is the general approach**, whatever the size of the work: analysis, capture, plan, implement. That's usually the order, but it rewinds when analysis changes.
- **GitHub is the archaeological record.** Diffs are the literal change. Issues, comments and PRs are the commentary that gives them context.
- **Plans are project artefacts.** They hold the planning, decisions and rationale, and are committed with the work.
- **ADRs are for strategic decisions.**
- **Cabinet** (`/opt/claude/cabinet`, paused) is the direction for agents working together. It consumes this config but doesn't own it.

## 2. Audit findings (14 Oct 2026)

### 2.1 `/do-hlr` imposes its own conventions

- `skills/do-hlr/SKILL.md` pre-flight step 0.4 creates `feat/$ARGUMENTS-<slug>`. portfoliobuilder's `.claude/rules/git-workflow.md` defines `{type}/{identifier}_{title}`: `fix/` is the default type, and long-running projects use hierarchical `project/#NN_title/master` and `project/#NN_title/#NNNN_sub-title`. Its history has 22 `fix/` and 20 `feature/` branches and no `feat/`.
- Pre-flight step 0.5 looks for `.claude/plans/YYYYMMDD-$ARGUMENTS-<slug>.md`. portfoliobuilder's docs say `yyyymmdd-name`, and 51 of its 52 plans follow them. In this repo, tracked plans live in `docs/` (`plans/` is gitignored), so step 0.5 never finds one.
- Pre-flight step 0.3 stops on a dirty tree. An uncommitted plan makes the tree dirty, and step 0.3 runs before step 0.5 commits the plan.

### 2.2 Two hierarchy mechanisms

- Pre-flight step 0.2 resolves a sub-HLR's base branch from a `Parent: #NNN` line in the body plus an existing `feat/NNN-*` branch.
- Pipeline step 3 creates GitHub sub-issues through `/plan:tasks`.

### 2.3 Competing layers

- **`agents/project-manager.md`** duplicates `/do-hlr`: orchestration, HLR conventions and `feat/123-name` branches. It also tells the agent to `git stash` before switching branches, which conflicts with portfoliobuilder's multi-session rules. Nothing references it.
- **`agents/white-hat.md`** has a generic core, but its "Domain-Specific Focus Areas" section and the examples in its description are about blockchain SDKs and wallets.
- **`/do-hlr` pipeline step 6** triggers the security gate on `crypto / key / signature / BEEF / merkle / interpreter / operations/`. Those patterns fit the BSV projects. They miss what matters in portfoliobuilder: authorisation (`ability.rb`), multi-tenancy, mass assignment.
- **`playbooks/specialist-review-timing.md`** (about 230 lines) has a useful generic core: plan reviews check intent and PR reviews check the diff. Around it are prescriptive checkpoint templates and portfoliobuilder material ("Lessons from PostgreSQL Upgrade", the strong-parameters example). The global `CLAUDE.md` "Reviews" section points at it.
- **`agents/technical-analyst.md`** has `memory: user` and tells the agent to "update your agent memory" with design decisions. That puts decisions where the record can't see them.

### 2.4 Unused frameworks

Usage is counted from `history.jsonl` on 14 Oct 2026. For comparison, `/do-hlr` has 295 uses, the last on 30 Sep.

- **spec-kit** (`commands/speckit` → `vendor/spec-kit/templates/commands`) has five uses, the last on 8 Jan 2026.
- **claude-workflow:** `commands/do`, `commands/plan` and `commands/setup.md` link to `vendor/claude-workflow`.
  - `/plan:tasks` is used internally by `/do-hlr` and was typed 53 times, the last on 19 Jun.
  - `/do:task` was typed 56 times. It ran alongside `/do-hlr` (in use since 27 Jan; converted to a skill on 21 Jun) and was last typed on 29 Jun. `/do-hlr` doesn't use it, so it looks superseded.
  - `/plan:brainstorm` has 3 uses and `/plan:feature` 1. `/do:changelog`, `/do:commit`, `/do:create-worktrees` and `/plan:prd` have never been used.
- **`README.md`** (line 15) lists `/merge-cleanup`, which doesn't exist as a command or a skill.

### 2.5 Preferences in the wrong place

- portfoliobuilder's auto-memory holds preferences that apply everywhere:
  - report distinct problems plainly;
  - one ticket per area, with line items;
  - prefer inline fixes over follow-ups.
- Its `MEMORY.md` "Learned (2026-02-05)" section restates the Decision Protocol and the HLR flow.
- The two-axis authorisation decision existed only in a memory file. It is now recorded on bettison-org/portfoliobuilder#1234, which already has an ADR acceptance criterion.

### 2.6 Working-tree drift

- `settings.json` has one uncommitted line: `"skipWorkflowUsageWarning": true`.
- Two Claude Code state directories are untracked: `skills/synced/` (the synced-skills cache) and `state/` (`mcp-discover-verdicts.json`).

## 3. Decisions

| # | Decision | Status |
|---|----------|--------|
| D1 | `/do-hlr` defers to the project's branch convention, falling back to `feat/NNN-slug`. Plan naming works the same way, falling back to `YYYYMMDD-slug`. | Agreed |
| D2 | Retire the project-manager agent. | Agreed |
| D3 | Drop spec-kit. | Agreed |
| D4 | GitHub sub-issues are the only hierarchy mechanism. | Agreed with the plan |
| D5 | Split material by audience. Team practice goes in a shareable work-organisation bundle under `profiles/` (created here, Step 7, on #7's mechanism). Personal style and private wiring stay inline in the global. | Agreed |
| D6 | The HLR conventions' portable part (what an HLR is, when to create one, the capture template, `project:hlr`, `[HLR]`, the sub-issue closure gotcha) moves into the work-organisation bundle; the `/do <issue>` invocation and the `workflow-guide.md` pointer stay inline as private wiring. | Settled 16 Oct |
| D7 | Replace `/do-hlr` with `/do` by **parallel-change**, not in-place rename: build `/do` as a new skill (Step 1), validate it while `/do-hlr` stays untouched as the fallback, then retire `/do-hlr` and sweep references at cutover (Step 8). "HLR" is a misnomer once it's the general approach. | Agreed 16 Oct |
| D8 | While #9 is underway, pause all other work — one focused effort. `/do-hlr` stays available only as the migration's rollback until cutover. | Agreed 16 Oct |
| D9 | Content leaving this repo lands first, by a small PR in its own repo (BSV security focus → bsv-ruby-sdk, bsv-wallet; `/do-hlr` references → portfoliobuilder, bsv-ruby-sdk). #9 merges only after those PRs. Retiring all `do:` commands, `/setup`, `/project:current` and `/plan:feature|prd|brainstorm` is confirmed. | Agreed 16 Oct |
| D10 | Machine-local edits (auto-memory, `agent-memory/`, `vendor/`) happen after #9 merges, because `git checkout master` can't roll them back. Deletions of untracked files go to `.trash/`, not `rm`. | Lead, 16 Oct (panel) |
| D11 | Steps 2–8 run in a fresh session as `/do 9`, resuming from the record — this proves the record is sufficient, and agent definitions and `CLAUDE.md` only load at session start. | Lead, 16 Oct (panel) |

## 4. Changes

**Execution.** #9 runs as one focused effort with all other work paused (D8), which keeps the parallel window clean and the cutover unambiguous. The step order is the execution order: do step 0, build and validate `/do` (step 1), carry out steps 2–7 using `/do`, then cut over and retire `/do-hlr` (step 8). `/do-hlr` stays available as the rollback until cutover. The waves, and what the specialist panel added to each step, are in §7.

### Step 0: prerequisite, a clean working tree

Do this before `/do-hlr 9`, because its pre-flight stops on a dirty tree.

- Commit the `skipWorkflowUsageWarning` line in `settings.json`. It's a UI preference, like the neighbouring `skip*` flags.
- Add `skills/synced/` and `state/` to `.gitignore`, under the "Local agent/session/usage state" block.
- This plan file stays untracked so that `/do-hlr` can make it the plan-first commit. The current pre-flight will flag it as dirt; tell it to proceed. Step 1's fix only helps later runs.

### Step 1: build `/do`, the project-following successor (new skill `skills/do/`)

Build `/do` **first**, as a new skill (start from a copy of `/do-hlr`), leaving `/do-hlr` untouched as the fallback (D7). This is the first and riskiest change: validate `/do` on a real issue, then run steps 2–7 with it before the step 8 cutover. The behaviour `/do` must have:

- **Branches:** read the project's convention from its `CLAUDE.md` and `.claude/rules/`, including hierarchical schemes. Fall back to `feat/NNN-slug`.
- **Plan:**
  - Use the plan the HLR links to, at any path.
  - Fall back to finding a plan by HLR number.
  - Name new plans by the project's convention, falling back to `YYYYMMDD-slug`.
  - Pre-flight treats that plan file as expected, not as a dirty tree.
- **Rewinds:** when analysis changes mid-flight, update the plan and say so on the HLR rather than leaving the plan stale.
- **Line items vs sub-issues:**
  - The HLR's checklist items are line items.
  - Only items big enough to need their own breakdown become sub-issues (via `/plan:tasks`).
  - A sub-HLR's parent comes from the GitHub sub-issue parent, not a `Parent: #NNN` line.
  - Its base branch follows the project's convention.
- **Security gate:**
  - Replace the BSV pattern list with "security-sensitive for this project".
  - Use the project's own patterns where it defines them (its review standards or `.architecture/members.yml`).
  - Otherwise use generic defaults: authentication and authorisation, crypto, input handling, deserialisation and secrets.

### Step 2: retire project-manager

- Delete `agents/project-manager.md`. Nothing references it.
- Delete its local agent memory (`agent-memory/project-manager/`, which is gitignored).

### Step 3: make white-hat project-agnostic (`agents/white-hat.md`)

- Remove the blockchain "Domain-Specific Focus Areas" section and the wallet and ECDH examples in the description.
- Add one line: take domain focus from the project's own config.
- The BSV focus moves into the BSV projects' own config (their `CLAUDE.md` or `.architecture/members.yml`). That change lands in those repos, so note it there when the work is done.

### Step 4: technical-analyst records decisions in the record (`agents/technical-analyst.md`)

- Decisions go to the plan, an HLR comment or an ADR.
- Agent memory holds recall aids only, such as pointers to where a decision lives.

### Step 5: slim the review playbook

- Keep the generic insight: review the plan before the work, review the diff before merge, and know that a plan review can't catch what isn't in the plan.
- Prefer folding it into `/do-hlr`'s specialist step and deleting the playbook. Failing that, trim it to about 20 lines.
- Move "Lessons from PostgreSQL Upgrade" and the strong-parameters example to portfoliobuilder, next to the plan or review they came from.
- Update the global `CLAUDE.md` "Reviews" section to match.

### Step 6: frameworks and README

- Remove the `commands/speckit` symlink, then delete `vendor/spec-kit` locally (`vendor/` is gitignored).
- For claude-workflow, keep `/plan:tasks`. Replace the `commands/plan` directory link with a link to that one command, and check `/plan:tasks` still resolves afterwards.
- Remove the `commands/do` and `commands/setup.md` links. This proposes retiring `/do:task`, superseded by `/do-hlr`; confirm before removing it. `/plan:brainstorm` goes too, because the global's Brainstorming section covers it.
- In the README, remove `/merge-cleanup` and check that every listed command exists.

### Step 7: preferences and memory

- Add "report distinct problems plainly" to the global `CLAUDE.md` Communication section. Multi-finding reports open with a numbered list of the distinct problems, in plain words, with no asides and precise nouns.
- Create `profiles/work-organisation.md` — the shareable bundle #7's mechanism enables — and put the team practices there (one ticket per area with line items; fix inline rather than filing follow-ups). Import it from the global `CLAUDE.md`. Don't put them inline.
- portfoliobuilder `MEMORY.md`:
  - drop "Learned (2026-02-05)", which is covered by the global;
  - reduce the authorisation memory to a pointer to #1234;
  - check the nonce-bug section for staleness.
- Auto-memory is machine-local and in no repo, so these edits need no PR.

### Step 8: cut over to `/do`, retire `/do-hlr` (agreed 16 Oct; after step 6, once `/do` is validated)

`/do` was built in step 1 and proven across steps 2–7. Cutover retires the old tool — do it only after step 6 has removed the `commands/do` symlink (which owns the `do:` namespace), so `/do` stands alone.

- Delete the old skill directory `skills/do-hlr/`.
- Sweep every reference from `/do-hlr` to `/do`: the global `CLAUDE.md` HLR section, `README.md`, `playbooks/`, `agents/`, and the machine-local auto-memories (no PR for those). This plan keeps the historical name in its audit.
- Verify `/do` resolves as a skill and no `/do-hlr` skill or `do:`-namespace command remains.

## 5. Out of scope

- How shared bundles reach a second developer (distribution beyond a local `@import`) belongs to #7's remit, not #9. The bundle's *creation* is now in scope here (Step 7), because #7 closed with only the mechanism and `git-workflow.md`.
- portfoliobuilder's authorisation ADR is already a criterion on bettison-org/portfoliobuilder#1234, and the decision is recorded there as a comment.
- portfoliobuilder's plan naming needs no change, because its docs and plans already agree.

## 6. Verification

- `git status` is clean before the step 1 build begins.
- `git grep -n -E "project-manager|speckit|merge-cleanup|BEEF" -- . ':!docs/*-plan.md'` finds nothing. (`git grep`, not `grep -rn`: the latter searches the untracked `skills/synced/` and skips symlinked skill folders.)
- `git ls-files -s | awk '$1==120000{print $4}' | while read l; do [ -e "$l" ] || echo "BROKEN $l"; done` prints nothing (today it prints `commands/project/current.md`).
- `grep -h '^name:' skills/*/SKILL.md | sort | uniq -d` prints nothing (no two skills share a name).
- `/context` in a fresh session shows the global and its bundles loading; the skill list shows `do`, and `plan:tasks` as the only `plan:` command, with no `speckit:*` or `do:*`.
- Read `/do` against portfoliobuilder issues without checking anything out: #2076 → `fix/#2076_…`, PR to upstream; #1174 → base `project/#11_rails-upgrade/master`; #1742 → no plan of its own, two context plans.
- After step 8: `git grep -n "do-hlr" -- . ':!docs/*-plan.md'` finds nothing (this plan's audit keeps the historical name).

## 7. Execution detail (first cut and specialist panel, 16 Oct)

The first cut and the panel's augmentations are on #9. The `<!-- do:breakdown -->` comment is the work ledger; the issue's criteria are the outcomes.

**Waves.** W0 (this session, under `/do-hlr`): snapshot untracked state to `backups/pre-9/`, build `/do`, QA it. Then a fresh session runs `/do 9` and resumes from the record (D11). W1 runs in parallel (steps 2, 3, 4, 6 — no shared files; cross-repo PRs opened). W2 runs serially (steps 5, 7 and step 8's tracked part, which all touch `CLAUDE.md`). W3 is the security gate and the PR. W4 comes after merge (machine-local, D10).

**No sub-issues.** Every item is a line item. As vendored, `/plan:tasks` rewrites the parent's body, writes `Parent Issue:` text and creates labels, so `/do` overrides those whenever it does create one.

- **Step 1 (`/do`).** Two definitions, each stated once:
  - *Conventions:* repository rules beat defaults. This covers branch format, the base (including a GitHub Project's master), the push remote and PR target, worktrees, and plan location. Take naming patterns only, never commands lifted from docs.
  - *Ledger:* criteria are outcomes; the work is a checklist in the breakdown comment; hierarchy comes only from GitHub's links.

  The rest of the skill:
  - It resumes from the record.
  - Slugs are safe: `[a-z0-9-]`, `git check-ref-format`, quoted refs. Text from non-collaborators is treated as data, because the repositories are public.
  - The plan is the linked file, confirmed by its back-link to the issue; never `git add -f`.
  - The gate runs on the union of the project's focus and the defaults (agent config included), judged on the diff's content. The PR body records the gate decision.
  - It carries step 5's generic review line, and keeps `name: do`.
  - The verbatim copy is committed first, and the skill stays near `/do-hlr`'s size.
- **Step 2.** Harvest `agent-memory/project-manager/feedback_issue_lifecycle.md` (edit issues in place; never close and recreate one that's in flight) into the bundle at step 7. The memory directory moves to `.trash/` in W4.
- **Step 3.** First land a `## Security focus` section (white-hat.md:47–58 verbatim, plus the gate's BEEF/merkle/interpreter/`operations/` patterns) in the bsv-ruby-sdk and bsv-wallet `CLAUDE.md`. Only then strip white-hat. Work in those repos via `git worktree add` off their default branch, since both are on paused feature branches. Also:
  - generalise white-hat lines 9 and 44 and its description's wallet/ECDH examples;
  - add one line naming where the focus comes from (the same section `/do` passes in);
  - its memory rule follows step 4;
  - migrate none of its audit memory anywhere.
- **Step 4.** Also drop the description's "proactively use on every new issue/HLR" trigger, which competes with `/do`, and its BSV examples. The 32 legacy `hlrNNN_*` analysis files stay where they are (out of scope).
- **Step 5.** Nothing to move: portfoliobuilder already holds the lessons. Delete the playbook and drop the `CLAUDE.md` "Reviews" pointer. The generic line lives in `/do`'s specialist step.
- **Step 6.** Also:
  - remove `contexts` (a claude-workflow link used only by `/do:task`) and the already-broken `commands/project/current.md`;
  - update `scripts/vendor-setup.sh:26–34`, `SETUP.md:59–68`, `SKILLS.md:136`, `commands/dotfiles-setup.md:51,124` and `skills/repo-consistency/SKILL.md:34,41,43,274`;
  - track `commands/plan/tasks.md` as a copy (with attribution) rather than a link, because the vendored file carries an uncommitted local patch (saved in `backups/pre-9/`);
  - use `git rm commands/plan`, never `rm -rf commands/plan/`, which follows the link into `vendor/`.
- **Step 7.** The bundle also takes D6's portable HLR conventions and the edit-in-place rule, and must mention neither `/do` nor `~/.claude`. In the global:
  - "Report distinct problems plainly" goes into Communication as one generalised bullet, with no incident detail, since the repository is public.
  - "TBC means ask" moves there too, from technical-analyst's memory.
  - "Don't modify files outside the objective" is reconciled with "fix inline": an opportunistic fix becomes a recorded line item.

  portfoliobuilder's `MEMORY.md` edits wait for W4.
- **Step 8.** Reword, don't just rename:
  - the `CLAUDE.md` HLR section, since `/do` isn't only for HLRs;
  - `workflow-guide.md:9`: line items, not sub-issues;
  - the guide's "small changes skip all of this" and "delete or archive the original".

  The `/do-hlr` references in other repos (portfoliobuilder `CLAUDE.md`, bsv-ruby-sdk `.claude/commands/codebase-audit.md`) go in the D9 PRs. The machine-local memory sweep happens in W4: read each file rather than search-and-replace, and leave history alone.

**Also out of scope:**
- bsv-ruby-sdk's own project-level `project-manager.md` and `technical-analyst.md`;
- the `portfoliobuilder-staging` clone;
- historical memories. For example, cabinet's `do-hlr-missing-piece.md` stays as it is: `/do` is a conventions successor, not Cabinet's M6 revision.

**Open questions for the user:**
- Should the other BSV-adjacent repos (runar, x402-rack, x100-rack, secp256k1-native, the x420 suite) get the security focus too?
- Should claude-workflow be dropped entirely? That's a follow-up after #9.

# Git strategy review

**Date:** 2026-11-17
**Status:** Review complete. Tier 1 landed (#31 and the vendoring PR); Tiers 2 and 3 are in progress under #30, with the decisions of 2026-11-18 in section 12.
**Tracking:** [sgbett/dotfiles-claude#30](https://github.com/sgbett/dotfiles-claude/issues/30)
**Sibling:** [#7 Config profiles](https://github.com/sgbett/dotfiles-claude/issues/7) delivered the `profiles/` mechanism this review builds on.

---

## 1. The question

The prompt: "I've stated on several occasions that I prefer rebasing branches, and yet I keep running into issues because apparently 'Rebasing it would have needed a force-push, which the git-workflow rules and /do forbid.'" Three readings were offered: indecision; a decision never propagated through the guiding documents; or relitigating a preference already rejected as a relic of manual git management.

Method: a scan of this repository's precedence hierarchy (global `CLAUDE.md`, imported profiles, skills, `settings.json`, playbooks, memory); cross-checks of the `CLAUDE.md` and referenced docs of the 20 most active repositories under `/opt` (modified since August 2026); the prompt history and plan files for the position over time; two research passes on current GitHub practice, with the lead resolving tie-breaks; and, on the follow-up, the live GitHub state of the collaborative repositories and the mechanics of sharing Claude Code configuration from a checkout.

## 2. Direct answers

**Indecision?** No. "Rebase" appears in the prompt history every month from December 2025 to November 2026, with no gap. The only axis that moved was landing: squash to merge commit, decided once on 2026-03-22 and never revisited.

**Decided but not propagated?** Yes, exactly this. On 2026-03-22: "this is going to be my global preference going forwards… make sure that nothing in ~/.claude/* contravenes this", and in the same hour, "I would mitigate that by doing a lot of rebasing on the feature branch before merging and that still remains an option." The landing rule reached the global `CLAUDE.md` on 2026-06-21 and the profile when it was extracted on 2026-08-18. The upkeep rule only ever reached portfoliobuilder's project file (2026-02-17, sharpened 2026-11-11 and 12). Every other repository and the profile said nothing about upkeep.

**Relitigating a rejected relic?** No. The relic was squash, the old "keep master clean" strategy. Rebase was explicitly retained the day squash was dropped, and the first-parent view is what made the landing choice stop mattering.

## 3. The distinct problems

Six, of which 1 and 2 are one problem (a vacuum in the global rule, filled by a Claude-authored ban); 3 is its symptom; 4 to 6 are separate drift found by the audit.

1. **`/do`'s force-push ban was Claude's, not the user's.** It entered the skill on 2026-06-21 by condensing Claude's own January 2026 draft of `commands/do-hlr.md` ("No force push: Never rewrites history or force pushes"), which mirrors Claude Code's built-in "NEVER force push to main/master" with the qualifier dropped. No prompt in that session mentions force-push; the commit body gives no reason. On 2026-11-14 it was moved into `/do`'s Invariants, the tier that overrides project conventions, so the 2026-11-11 project rule ("Rebase it: locally, then `git push --force-with-lease`") was structurally outranked by a rule nobody decided. A parenthetical added on 2026-11-13, "developers' pushed commits are permanent", was a note on the Visibility rule about sub-agents mid-task, not the ban's rationale.
2. **`profiles/git-workflow.md` was silent on branch upkeep.** It said how PRs land and never how a branch is kept current. The stated principle of 2026-06-20, "I don't want to have to configure git per project… per project stuff goes stale", was right; this axis never got its global line.
3. **The 13 to 17 November bsv-ruby-sdk session was internally inconsistent.** It rebased and force-pushed with a lease on three PRs, and merged master into two others by hand during a `/do` pre-flight, unannounced, plus one more on a fork for an advisory. The justification cited "the git-workflow rules and `/do`"; the profile had no force-push line. That repository had no back-merges before November.
4. **"Merge commits, not squash" was prose-only everywhere except bsv-wallet.** Every other repository left GitHub's default merge methods enabled; secp256k1-native rebase-merged all four of its PRs since August. `settings.json`'s force-push `ask` is also leaky (`git push origin --force`, `+ref` and `gh api` ref updates fall through to the broad `git *` allow), a breadth kept deliberately in #12.
5. **The personal-repo carve-out was declared four different ways** across the personal workspaces and not at all in several repositories. amanuensimus, which is public, cited a stale rationale ("pending the per-project profiles feature"). All four gems' `/release` commands (bsv-ruby-sdk, bsv-wallet, secp256k1-native, x402-rack) push straight to master against the rule, and bsv-wallet's protection now rejects that.
6. **Stale text:** portfoliobuilder `docs/worktree-setup.md` "Use merge (not rebase)" (January 2026, never updated); its ADR-002 lists `git revert` as a rollback option; one private repository defaults to `main`.

## 4. The position over time

| Axis | To February 2026 | From March 2026 | Changed? | Evidence |
|---|---|---|---|---|
| Branch upkeep | rebase onto base | rebase onto base | No | monthly prompts; 2026-03-22 caveat; 2026-08-14; 2026-11-11 and 12 "yes to all" |
| Landing | squash | merge commit, never fast-forward | Yes | 2026-02-15 question, 2026-03-22 decision; 2026-04-15 "I said merge it" |
| Force-push own branch | routine | routine | No in prompts; banned by `/do` from 2026-06-21 | 2026-08-15 was a collaborator's branch: the shared-branch exception, applied but unwritten |
| `git revert` | never | never | No | January, April twice, June |

The one apparent counter-example, 2026-08-15 "instead of rebase merge master", was a PR carrying a collaborator's commit. The timeline shows the lead force-pushed it after the collaborator had finished and then merged master in: the own-vs-shared line applied correctly to a branch whose other committer was done. It just wasn't written down.

## 5. Estate audit (20 repositories, cut-off August 2026)

| Cluster | Repositories | Written landing rule | Written upkeep rule | Server-side enforcement |
|---|---|---|---|---|
| Private, commercial | portfoliobuilder, portfoliobuilder-support, rcpsych-intel and one other | portfoliobuilder and -support yes; others none | portfoliobuilder only | checked; private repositories' state stays in the session, not in this public file |
| Open-source BSV | bsv-ruby-sdk, bsv-wallet, secp256k1-native, x402-rack, bsv-x402, and one not yet public | sdk `CONTRIBUTING.md` yes; wallet README no strategy; rest none | none | bsv-wallet only (`allowed_merge_methods: ["merge"]`, classic protection with `enforce_admins`) |
| Claude workspaces | cabinet, amanuensimus, one organisation workspace, and five personal workspaces | cabinet yes; the personal ones declare the carve-out variously; two undeclared | none | cabinet checked, state in the session; the personal ones none |
| External clones | bsv-blockchain SDKs and toolboxes, Homebrew | upstream's | not ours | not ours |

There is no public/private split in the landing rule: bsv-ruby-sdk's contributor-facing `CONTRIBUTING.md` says the same as the private repositories. The real split is collaborative versus personal, orthogonal to visibility and organisation.

Live state on 2026-11-17, from `gh api`: sgbett/bsv-wallet, which is public, has the full set (PR required, merge only, force-push blocked, no update-branch button). The private collaborative repositories were checked the same way; their per-repository state and who holds what access are in the session record, not in this public file, and the gaps found are Tier 2's work.

## 6. Are we off the mark? Verdict

Close to the mark; defensible mainstream. The only outlier was the blanket ban, and the only minority element is "never squash".

- **The preference has a name on three of the four major platforms:** GitLab "Merge commit with semi-linear history", Azure DevOps "Semi-linear merge: rebase source commits onto the target and create a two-parent merge", Bitbucket "Rebase, merge (rebase + merge --no-ff)". GitHub alone lacks it as a merge method, but its product does it: "Update with rebase" (2022), native stacked PRs that "automatically rebase and retarget" (GA October 2026), and its CLI guide documents rebase then `--force-with-lease`.
- **The mainstream force-push line is own-vs-shared, not pushed-vs-unpushed.** Pro Git: "If you rebase commits that have been pushed, but that no one else has based commits from, you'll also be fine." `gitworkflows(7)`: "a topic that has been merged elsewhere should not be rebased." Kernel documentation: "Do not rebase a branch that contains history created by others", and "Linus is adamant that he would much rather see merge conflicts than unnecessary back merges." Atlassian's golden rule defines "public" by use, not by having been pushed. Agent-era guidance (October 2026): "Agents rebase their own task branches freely; shared branches (main, release) are append-only and protected." Every stacking tool (Graphite, jj, git-spice, ghstack) force-pushes own branches by default with a lease.
- **The opposing camp's best citation** is one GitHub docs page ("bad practice to rebase commits when you've already pushed", unconditional) plus the unattended cloud bots. Copilot's cloud agent and `claude-code-action` never rebase or force-push, and the latter says "If you need to rebase, do it yourself locally, or with the Claude Code CLI." `/do` is an attended local-CLI skill: it had imported a cloud-bot constraint into the one context the vendors say rebasing belongs in.
- **Squash** remains common and the published guidance is "be pragmatic"; merge commit plus first-parent is a recognised alternative. One caveat: GitHub's web UI still has no `--first-parent` view (request open since 2023), so the rationale holds for CLI and desktop clients, not github.com.
- **Terminology.** Strict semi-linear means every branch is rebased onto the current base at merge time, which GitLab and Azure enforce. The practice here is rebase only when needed, with strict status checks off so hashes stay stable: "rebase-updated, merge-commit landing", semi-linear for the PRs that got rebased. The non-strict form is the recommendation; the strict form costs a rebase and a CI rerun per PR, and GitHub's merge queue won't do the rebase.
- **Two technical details for the rule:** `--force-with-lease` alone is defeated by background fetches, which `/do` and `/copilot-check` perform, so pair it with `--force-if-includes` (git 2.30 or later). And `/do`'s one genuine rebase cost is broken hash citations in ledgers and PR bodies (the 2026-10-24 incident; citing PRs rather than commits was the mitigation), a reason to cite PRs and paths, not a reason to ban.

## 7. The principle, made deterministic

The principle decomposes into three enforcement layers that need almost no prose, plus one judgement call.

- **Server side, rulesets.** On master: pull request required, `allowed_merge_methods` set to merge only, `non_fast_forward`, `deletion`, strict status checks off, `allow_update_branch` off (the button's default is a merge from the base, with rebase a second click; `gh pr update-branch --rebase` works without it), `allow_squash_merge` off at repository level. The template is `profiles/git-workflow/ruleset.json` with `repository.json`, targeting `~DEFAULT_BRANCH` so a rename or a repository still on `main` is covered, and carrying no bypass actors: an admin bypass exempts the account the agent pushes as, which is what the rule exists to bind, so bsv-wallet's rulesets today bind nobody. On work branches: `required_linear_history`, which rejects any push containing a merge commit, so a back-merge becomes impossible and rebase is the only way to update. That one rule makes the principle enforced rather than described. It must exclude master, `project/*` and `releases/*`, and it needs a check on a scratch repository first. Never `required_linear_history` on master: on GitHub that bans merge commits.
- **Local side, a hook.** Permission patterns can't express "allow with-lease, ask on bare force": `Bash(git push --force*)` is a prefix glob that matches `--force-with-lease` too, which is why every with-lease push prompts today. A repository-committed `PreToolUse` hook can: deny a bare `--force`, `-f` or `+ref`, and any force or deletion aimed at a base branch; ask before a lease push to a branch whose remote range has another author; and say nothing otherwise. It never answers `allow`, which would silence the permission rules and ship a grant into every collaborator's session, and it fails closed: whatever it cannot read becomes an ask. It sees only the literal command text, so a push inside a script or alias is invisible and the ruleset is the control.
- **Local side, git config.** `pull.rebase=true`, `push.useForceIfIncludes=true`, `rebase.autoStash=true`. Set globally on the owner's machine on 2026-11-18; the runbook gives collaborators the same lines.
- **`/do`.** Read the live ruleset rather than parse prose: a `pull_request` rule on the base means collaborative, its `allowed_merge_methods` gives the merge flag, no rule means personal. The `CLAUDE.md` declaration is the fallback for offline or non-GitHub repositories, and `repo-consistency` flags any disagreement between the two.

The remaining judgement is "is anyone else on this branch?". A committer check only prompts it: it can't see `/do`'s developers, who commit under the lead's identity with a `Co-Authored-By` trailer, and can't tell a collaborator who has finished from one still working, so the hook asks rather than blocks. The ask is a permission prompt the user answers, not `/do`: `/do` keeps out of the case by its own invariant, never rewriting the work branch while a developer is mid-task. The profile text then reduces to the rule and a pointer to what enforces it.

## 8. Profiles: distribution to collaborators

The intent of `profiles/` is shared configuration that crosses projects, users and machines: "while you're in my house, we do it this way". A collaborator won't point their `~/.claude` at this repository, so the mechanism has to be the checkout.

What Claude Code loads from any user's checkout, confirmed against the current documentation: `CLAUDE.md`, `.claude/rules/*.md`, `.claude/skills/`, and `.claude/settings.json` (permissions and hooks, after a one-time workspace-trust dialog in interactive use; in `claude -p` they run without it, so hook scripts are reviewed like any code). What it does not load: anything imported from `~/.claude/`, which silently yields nothing on a machine without the path; and plugins, which carry skills, hooks, agents and MCP servers but not rules text, and which a repository's `enabledPlugins` cannot install or prompt for (an open feature request). No 2026 mechanism exists for remote or URL imports, team-scoped settings or repository-declared rule inheritance.

So the distribution model is:

- **Rules text:** vendored verbatim into `.claude/rules/git-workflow.md`, with a header naming the source; repository-specific differences in a second file; `repo-consistency` diffs the copy, header lines skipped, against the source.
- **Enforcement:** the hook script and settings snippet committed in the repository, or later packaged as a plugin at the cost of one documented install command.
- **Server rulesets:** the only lever that works regardless of the collaborator's tooling.
- **Setup runbook:** `git config` lines, the trust dialog, the rebase procedure. The collaborator's own history shows pull-merges, so `pull.rebase` is the first line.

"Profile-ready" for what is built now: the profile text stays free of `/do` and home paths; enforcement pieces live as files beside it; the per-repository declaration is one line. One accepted cost: for the owner, the global import and the vendored copy both load.

## 9. Natural splits and tier assignments

Three tiers, not public/private. Decided 2026-11-17.

- **Collaborative** (PR-only, merge commits, rebase upkeep, ruleset-enforced): portfoliobuilder, portfoliobuilder-support, cabinet, bsv-ruby-sdk, bsv-wallet, secp256k1-native, x402-rack, bsv-x402, two private repositories, and every repository under the private organisation; the session record names them. Visibility and organisation don't change the rules, only whether contributor-facing docs restate them.
- **Personal** (commit straight to master, one declared line): rcpsych-intel, amanuensimus, this repository (per the existing memory), and the remaining personal workspaces.
- **External clones** (upstream's rules; the profile doesn't apply): bsv-blockchain's repositories, Homebrew.

## 10. Cleanup

**Tier 1, the actual conflict (done under #30):** the profile gains the upkeep, force-push scope and cite-PRs lines; `/do`'s Git invariant narrows scope only and defers to the profile, with provenance in the commit body; portfoliobuilder's rule splits into a vendored copy of the profile plus a differences file; the memory note records the standing preference.

**Tier 2, enforcement (in progress under #30):** the ruleset template (`profiles/git-workflow/ruleset.json` and `repository.json`) applied to every collaborative repository by the runbook's commands, no bypass actors, classic protection removed only where it adds nothing; the optional work-branch linear-history ruleset deferred; the push-guard hook, `hooks.json` and `setup.md` as profile assets, vendored into portfoliobuilder once this lands; the owner's `ask` globs narrowed to a bare force and the hook wired into the global settings; `git-settings audit` under `repo-consistency` reporting drift. Deferred from the security gate of 2026-11-18, the owner's call: a second ruleset (`deletion`, `non_fast_forward`) for `project/**` and `releases/**`, which the default-branch ruleset leaves to the hook; a tag ruleset, so a release tag can't be moved; and an ask on a non-GET `gh api` call, which the broad `gh api` allow of #12 lets through to the refs API and the rulesets themselves.

**Tier 3, drift (in progress under #30):** one standard tier line (`Git tier: collaborative` or `Git tier: personal`) in each repository's `CLAUDE.md`; amanuensimus's stale rationale; the gem release bump routed via PR with the tag pushed direct; the stale lines in portfoliobuilder's `docs/worktree-setup.md` and ADR-002; the repository still on `main` renamed; `repo-consistency`'s git section running the audit.

## 11. Rules against future slippage

1. **One home per axis.** Landing, upkeep, force-push and revert live in `profiles/git-workflow.md`; a project file states only differences and says why.
2. **Rule provenance.** A commit adding or changing a policy line in a profile or skill names who decided and when in its body. The ban would have failed this test on day one.
3. **Skills don't make git policy.** `/do` and `/copilot-check` invariants may narrow scope (mid-run, base branches) and must point at the profile for the rest.
4. **No silent workarounds.** When a rule blocks the natural action, stop and ask. The 13 November back-merge was improvised in silence, which the plan file of 17 November called "my failure".
5. **Enforce what's enforceable, audit the rest.** Rulesets for the collaborative tier; `repo-consistency` for the prose and the live settings.

## 12. Decisions of record

- 2026-03-22: landing is merge commit, not squash; rebase on the feature branch retained.
- 2026-04-15: a real merge commit, never a fast-forward.
- 2026-11-11 and 12: rebase when needed, with a lease, as the project rule; "you're not the problem".
- 2026-11-17: the force-push line is own-vs-shared branch; the `/do` ban goes; the review is persisted here with #30 tracking the cleanup; tier assignments as in section 9; the vendored-profile distribution model.
- 2026-11-18: the release bump goes by PR and the tag direct, so the template carries no bypass actors and the profile no exception line; the repository on `main` is renamed; the push-guard never answers `allow` and fails closed; the owner's `ask` globs narrow to a bare force and the hook runs globally; the template is applied to every collaborative repository, dry-run first; `git reset` undoes unlanded work and landed work is fixed forward.

# Resuming

`/do`'s pre-flight steps 5 and 7, when the issue has a ledger or trusted work is already in flight.

- **Start from the commit `check` read**, `branch.remote_tip`, which it fetched through the push URLs it checked; never pull, fetch or check out the branch through the remote's name, whose fetch URL can name another repository. Resuming from the push remote (`resume_push_remote`), start at that commit; on a local branch behind it (`resume_local`), fast-forward to it.
- **Beside a checked-out PR** (`branch.fresh_worktree`): the run never resumes on that local branch, so leave it untouched and build in a new worktree detached at `branch.remote_tip`, pushing `HEAD` to the branch.
- **From a ledger,** skip pipeline steps 1–3 and continue from its first unticked item this run builds (`facts`' `ledger.first_unbuilt`). Edit the ledger comment (`ledger.comment_id`) rather than posting another.
- **Unticked doesn't mean unbuilt.** Step 7 ticks only once the PR is open, so check the branch's commits before rebuilding an item, and send work already there straight to QA.
- **Every item ticked, PR open:** go straight to step 7's chain.
- **Without a ledger, seed one from trusted work in flight** — a branch on the resolved push remote, a PR by a trusted author whose head is there, linked sub-issues by trusted authors (`facts`' `branches` and `sub_issues`, each with its author's `trusted`) — skipping any sub-issue the Visibility invariant won't let you name, and update that PR. A branch whose name only `session_only.unusable_branches` gives is never a base or branch: name it to the user.
- **Never check out, build or test a branch `check` didn't accept:** another fork's, a checked-out PR, or an untrusted author's.

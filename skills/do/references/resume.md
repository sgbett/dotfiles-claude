# Resuming

`/do`'s pre-flight step 7, when the issue has a ledger or trusted work is already in flight. `facts` and `check` list this file in `read` whenever that's so.

- **From a ledger,** skip pipeline steps 1–3 and continue from its first unticked item this run builds (`facts`' `ledger.first_unbuilt`). Edit the ledger comment (`ledger.comment_id`) rather than posting another.
- **Unticked doesn't mean unbuilt.** Step 7 ticks only once the PR is open, so check the branch's commits before rebuilding an item, and send work already there straight to QA.
- **Without a ledger, seed one from trusted work in flight** — a branch on the resolved push remote, a PR by a trusted author whose head is there, linked sub-issues by trusted authors (`facts`' `branches` and `sub_issues`, each with its author's `trusted`) — skipping any sub-issue the Visibility rule won't let you name, and update that PR.
- **Never check out, build or test a branch `check` didn't accept:** another fork's, a checked-out PR (reason `checked_out_pr`), or an untrusted author's (reason `untrusted_pull_request`). A local branch with commits the push remote lacks needs the user's yes first (reason `local_branch_unpushed`).

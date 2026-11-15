# frozen_string_literal: true

module CopilotCheck
  module Reasons
    UNDO_READY = 'Run gh pr ready --undo for it and report that instead: jobs the ready event started keep running.'

    # Each reason's message, keyed by the reason.
    MESSAGES = {
      not_a_pull_request_number: "The argument isn't a pull request number. Tell the user that /copilot-check " \
                                 "takes a bare number, or nothing on the pull request's branch, as the repository " \
                                 "is always this checkout's.",
      chained_without_number: 'The argument is chained with no pull request number before it, yet /do, which ' \
                              'chains a run, always names the pull request it hands on, as in 18 chained. Tell ' \
                              "the user that /do's hand-off lacks the number.",
      pull_request_not_open: "The pull request isn't open: it has been merged or closed (pull_request.state), so " \
                             'there is nothing for /copilot-check to fix. Tell the user.',
      no_pull_request_checkout: "No checkout of this repository, the working directory's or a worktree of it, " \
                                "has the pull request's branch (pull_request.head_branch) checked out, so the run " \
                                'has nowhere to make its fixes. Tell the user to check it out in one, then run ' \
                                '/copilot-check again.',
      checkout_runs_scripts: "The pull request's branch is checked out where these scripts run from " \
                             "(session_only.checkout), so the run's fixes would change the scripts as they run. " \
                             'Tell the user to switch that checkout to another branch and check the pull ' \
                             "request's branch out in a worktree of it, as git worktree add does, then run " \
                             '/copilot-check again.',
      no_upstream: "The branch checked out at session_only.checkout doesn't track the pull request's branch " \
                   '(pull_request.head_branch) on a remote, where the run pushes its fixes. Tell the user to set ' \
                   'its upstream to that branch, as git branch --set-upstream-to does, then run /copilot-check ' \
                   'again.',
      checkout_not_at_head: "The checkout with the pull request's branch (session_only.checkout) isn't at the pull " \
                            "request's head: its HEAD is local_head, the head pull_request.head, so the run's " \
                            "fixes wouldn't build on what Copilot reviews. Tell the user to push or pull first, so " \
                            'the two match, then run /copilot-check again.',
      fork_pull_request: "The pull request comes from a fork: its author isn't trusted, yet controls the code the " \
                         "verifiers read and the fixes would build on, and a yes means Phase 4 runs the fork's specs " \
                         'and linter as the owner. Ask the user whether to go on, saying so; on a yes, run setup ' \
                         'again with accept_with added, which holds while pull_request.head is the head.',
      scripts_unreviewed: 'The checkout these scripts run from has changes under skills/copilot-check or ' \
                          "skills/_support or to the files that pick their Ruby, or its HEAD isn't in its default " \
                          'branch, so they may not be the reviewed scripts (session_only.scripts_changes). Ask the ' \
                          'user whether to go on with them; on a yes, run setup again with accept_with added.',
      copilot_id_changed: "A review or thread under Copilot's login carries an id other than the identity table's " \
                          "BOT_kgDOCnlnWA: Copilot's account id has changed. Stop and tell the user to update the " \
                          'identity table and CopilotCheck::Copilot::BOT_ID; never treat this as convergence.',
      copilot_timeout: 'No new Copilot review came within 15 minutes (failed_polls counts the polls that could not ' \
                       "read GitHub, and session_only.error holds the last one's error). Copilot occasionally does " \
                       'not review, and nothing else may notice: say so plainly in the report.',
      copilot_unrecognised: "Copilot's latest review has inline comments, but no review thread was started by " \
                            "Copilot's id: the filters no longer recognise Copilot. Stop and flag it; never treat " \
                            'this as convergence.',
      threads_overflow: 'The pull request has more than 100 review threads, Copilot reviews or comments, more than ' \
                        "the thread fetch reads, so it can't show that none is still to do. Stop and tell the user.",
      head_changed: 'The pull request was marked ready, but its head is no longer the commit promote-check ' \
                    "checked (pull_request.head is the new one). #{UNDO_READY}",
      head_unreadable: 'The pull request was marked ready, but its head could not be read back ' \
                       "(session_only.error). #{UNDO_READY}",
      ready_state_unexpected: 'The pull request was marked ready, but GitHub shows it closed, merged, still a draft ' \
                              "or with auto-merge on (pull_request.state, is_draft, auto_merge). #{UNDO_READY} If " \
                              'auto_merge is true, tell the user: gh pr merge --disable-auto turns it off.',
      not_open: "The pull request isn't open.",
      not_a_draft: "The pull request isn't a draft now.",
      no_draft_flow: "The rules don't say pull requests open as drafts, and the run wasn't chained from /do, " \
                     'whose conventions open the draft for the loop.',
      merge_not_owners_step: "The rules don't list merging as a later step the owner takes, and the run wasn't " \
                             'chained from /do, whose invariants leave merging to the owner.',
      not_draft_at_start: "The pull request wasn't a draft when the run began, as Phase 0 recorded it.",
      not_converged: "The run didn't converge: it halted, timed out, stopped or failed to push.",
      local_head_differs: "The checkout's HEAD (local_head) isn't the pull request's head commit.",
      copilot_not_on_head: "Copilot's latest review isn't of the pull request's head commit, or there is none.",
      todo_threads: 'A fresh fetch finds review threads still to do (copilot.todo_threads): unresolved, started ' \
                    "by Copilot, and with a last comment that isn't ours.",
      unanswered_reviews: 'A fresh fetch finds Copilot reviews still to do (copilot.todo_reviews) that no comment ' \
                          'of ours marks answered and that the run did not find free of findings ' \
                          '(--reviews-without-findings).',
      review_bodies_unread: 'A review given as free of findings has no review-<id>.md in the bodies directory that ' \
                            'is its body now (copilot.unread_reviews).',
      not_viewers_own: "The pull request's author isn't the authenticated user.",
      from_fork: 'The pull request comes from a fork.',
      files_unlisted: "The pull request's changed files could not all be listed, as GitHub lists at most 3,000, so " \
                      'changes to workflows or rules files cannot be ruled out.',
      protected_paths_changed: 'The pull request changes a path under .github/workflows/ or .github/actions/, ' \
                               "Copilot's rubric .github/copilot-instructions.md, a file named CLAUDE.md, " \
                               'CLAUDE.local.md or .mcp.json, or a path under a .claude directory ' \
                               '(files.github_text.protected_paths), so what GitHub Actions runs, what Copilot ' \
                               "reviews against or what Claude Code loads from the checkout may not be the base's.",
      no_checks: 'No check has run on the head.',
      checks_pending: 'A check on the head is pending.',
      checks_cancelled: 'A check on the head was cancelled.',
      undocumented_failures: 'A check on the head failed, and the rules do not document that failure: by its ' \
                             'check name, with every one of its failure annotations, read through a GitHub ' \
                             'Actions job link in this repository, carrying a text they give for it.',
      not_mergeable: "GitHub doesn't report the pull request as MERGEABLE, after one re-read if it was UNKNOWN.",
      auto_merge_on: 'Auto-merge is on.'
    }.transform_values(&:freeze).freeze
  end
end

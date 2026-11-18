# frozen_string_literal: true

require_relative 'hold_messages'

module CopilotCheck
  module Reasons
    UNDO_READY = 'Run gh pr ready --undo for it and report that instead: jobs the ready event started keep running.'

    # Each reason's message, keyed by the reason: the scripts' stops and
    # asks, then the verdict's holds (HOLD_MESSAGES).
    MESSAGES = {
      not_a_pull_request_number: "The argument isn't a pull request number. Tell the user that /copilot-check " \
                                 "takes a bare number, or nothing on the pull request's branch, as the repository " \
                                 "is always this checkout's.",
      chained_without_number: 'The argument is chained with no pull request number before it, yet /do, which ' \
                              'chains a run, always names the pull request it hands on, as in 18 chained. Tell ' \
                              "the user that /do's hand-off lacks the number.",
      pull_request_not_open: "The pull request isn't open: it has been merged or closed (pull_request.state), so " \
                             'there is nothing for /copilot-check to fix. Tell the user.',
      pull_request_auto_merge: 'Auto-merge is on (pull_request.auto_merge), so a push would merge the pull request ' \
                               'on green with nobody looking. Tell the user: gh pr merge --disable-auto turns it ' \
                               'off, and /copilot-check then resumes.',
      no_pull_request_checkout: "No checkout of this repository, the working directory's or a worktree of it, " \
                                "has the pull request's branch (pull_request.head_branch) checked out, so the run " \
                                'has nowhere to make its fixes. Tell the user to check it out in one, then run ' \
                                '/copilot-check again.',
      checkout_path_unsafe: "The path of the checkout with the pull request's branch checked out " \
                            '(session_only.checkout) holds a single quote or a control character, so the ' \
                            "run's command lines, which single-quote it, can't name it safely. Tell the user to " \
                            'move that checkout to a path without either, as git worktree move does for a linked ' \
                            'worktree, then run /copilot-check again.',
      checkout_mismatch: "The path git lists for the worktree with the pull request's branch checked out doesn't " \
                         "hold that worktree now: it resolves to session_only.checkout, which isn't a checkout of " \
                         'this repository with that branch at the commit git lists (local_head), as when the ' \
                         'directory has been replaced or swapped for a link. Tell the user to check what is at ' \
                         'that path and fix the worktree, as git worktree list and git worktree repair help to, ' \
                         'then run /copilot-check again.',
      checkout_runs_scripts: "The pull request's branch is checked out where these scripts run from " \
                             "(session_only.checkout), so the run's fixes would change the scripts as they run. " \
                             'Tell the user to switch that checkout to another branch and check the pull ' \
                             "request's branch out in a worktree of it, as git worktree add does, then run " \
                             '/copilot-check again.',
      no_upstream: "The branch checked out at session_only.checkout doesn't track the pull request's branch " \
                   '(pull_request.head_branch) on a remote, where the run pushes its fixes. Tell the user to set ' \
                   'its upstream to that branch, as git branch --set-upstream-to does, then run /copilot-check ' \
                   'again.',
      push_remote_not_head_repository: "The branch checked out at session_only.checkout tracks the pull request's " \
                                       "branch on a remote that doesn't push to the pull request's head " \
                                       'repository (pull_request.head_repository, null when GitHub names none) ' \
                                       "alone: a URL it pushes to is on another host, isn't a repository URL gh " \
                                       'reads, or resolves through GitHub to another repository, so the run would ' \
                                       'push its fixes there. Tell the user to set its upstream to that branch on ' \
                                       'a remote of the head repository, as git branch --set-upstream-to does, ' \
                                       'then run /copilot-check again.',
      checkout_not_at_head: "The checkout with the pull request's branch (session_only.checkout) isn't at the pull " \
                            "request's head: its HEAD is local_head, the head pull_request.head, so the run's " \
                            "fixes wouldn't build on what Copilot reviews. Tell the user to push or pull first, so " \
                            'the two match, then run /copilot-check again.',
      fork_pull_request: "The pull request comes from a fork someone else owns: they aren't trusted, yet control " \
                         'the code the verifiers read and the fixes would build on, and a yes means Phase 4 runs ' \
                         "the fork's specs and linter as the owner. Ask the user whether to go on, saying so; on a " \
                         'yes, run setup again with accept_with added, which holds while pull_request.head is the ' \
                         'head.',
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
                              'auto_merge is true, tell the user: gh pr merge --disable-auto turns it off.'
    }.transform_values(&:freeze).merge(HOLD_MESSAGES).freeze
  end
end

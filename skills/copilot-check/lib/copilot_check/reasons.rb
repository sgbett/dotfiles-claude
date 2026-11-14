# frozen_string_literal: true

module CopilotCheck
  # Every reason /copilot-check's scripts can stop or ask for, and every
  # reason promote-check's verdict can hold a draft for, each with its
  # message. A message is a constant, so no GitHub text can reach one;
  # whatever the lead needs travels beside it in validated fields.
  module Reasons
    NOT_A_PULL_REQUEST_NUMBER = :not_a_pull_request_number
    PULL_REQUEST_NOT_OPEN = :pull_request_not_open
    FORK_PULL_REQUEST = :fork_pull_request
    SCRIPTS_UNREVIEWED = SkillSupport::ScriptsCheckout::REASON
    COPILOT_ID_CHANGED = :copilot_id_changed
    COPILOT_UNRECOGNISED = :copilot_unrecognised
    THREADS_OVERFLOW = :threads_overflow
    COPILOT_TIMEOUT = :copilot_timeout
    HEAD_CHANGED = :head_changed
    HEAD_UNREADABLE = :head_unreadable
    READY_STATE_UNEXPECTED = :ready_state_unexpected

    # The thread fetch's stops (Threads), which leave nothing to judge.
    THREAD_STOPS = [COPILOT_ID_CHANGED, COPILOT_UNRECOGNISED, THREADS_OVERFLOW].freeze
    # setup's whole enum: an argument that names no pull request, one that
    # isn't open, the asks on a fork's and on scripts that may not be the
    # reviewed ones, and Copilot's latest review under another id.
    SETUP = [NOT_A_PULL_REQUEST_NUMBER, PULL_REQUEST_NOT_OPEN, FORK_PULL_REQUEST, SCRIPTS_UNREVIEWED,
             COPILOT_ID_CHANGED].freeze
    # threads': `fetch` and `resolve` stop only where the thread fetch does.
    THREADS = THREAD_STOPS
    # rereview's: `request` never stops, and `watch` stops on Copilot's
    # latest review under another id, or on none newer within 15 minutes.
    REREVIEW = [COPILOT_ID_CHANGED, COPILOT_TIMEOUT].freeze
    # promote-check's whole enum of stops: `check` stops only where the
    # thread fetch does, and `verify` on anything but the head it was given,
    # open, ready and without auto-merge.
    PROMOTE_CHECK = (THREAD_STOPS + [HEAD_CHANGED, HEAD_UNREADABLE, READY_STATE_UNEXPECTED]).freeze
    # Every reason a script can stop or ask for.
    ALL = (SETUP | THREADS | REREVIEW | PROMOTE_CHECK).freeze

    # Why promote-check's verdict holds a draft: Phase 6's conditions, in its
    # order, each named for how it fails.
    HOLD = %i[not_open not_a_draft no_draft_flow merge_not_owners_step not_draft_at_start not_converged
              local_head_differs copilot_not_on_head todo_threads unanswered_reviews review_bodies_unread
              not_viewers_own from_fork files_unlisted protected_paths_changed no_checks checks_pending
              checks_cancelled undocumented_failures not_mergeable auto_merge_on].freeze

    UNDO_READY = 'Run gh pr ready --undo for it and report that instead: jobs the ready event started keep running.'

    MESSAGES = {
      not_a_pull_request_number: "The argument isn't a pull request number. Tell the user that /copilot-check " \
                                 "takes a bare number, or nothing on the pull request's branch, as the repository " \
                                 "is always this checkout's.",
      pull_request_not_open: "The pull request isn't open: it has been merged or closed (pull_request.state), so " \
                             'there is nothing for /copilot-check to fix. Tell the user.',
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
                       "not review, and as its review only comments it can't be a required approval, so nothing " \
                       'else will notice: say so plainly in the report.',
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
      no_draft_flow: "The rules don't say pull requests open as drafts.",
      merge_not_owners_step: "The rules don't list merging as a later step the owner takes.",
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
      protected_paths_changed: 'The pull request changes a path under .github/workflows/ or .github/actions/, a ' \
                               'file named CLAUDE.md, CLAUDE.local.md or .mcp.json, or a path under a .claude ' \
                               'directory (files.github_text.protected_paths), so what GitHub Actions runs or ' \
                               "Claude Code loads from the checkout may not be the base's.",
      no_checks: 'No check has run on the head.',
      checks_pending: 'A check on the head is pending.',
      checks_cancelled: 'A check on the head was cancelled.',
      undocumented_failures: 'A check on the head failed, and the rules do not document that failure: by its ' \
                             'check name, with every one of its failure annotations, read through a GitHub ' \
                             'Actions job link in this repository, carrying a text they give for it.',
      not_mergeable: "GitHub doesn't report the pull request as MERGEABLE, after one re-read if it was UNKNOWN.",
      auto_merge_on: 'Auto-merge is on.'
    }.transform_values(&:freeze).freeze

    module_function

    def stop(reason, **fields)
      SkillSupport::Outcome.stop(reason, MESSAGES.fetch(reason), **fields)
    end

    # One entry of an ask's list; +details+ carries what the answer needs.
    def ask(reason, **details)
      { reason: reason, message: MESSAGES.fetch(reason), **details }
    end

    # One entry of a HOLD verdict's reasons.
    def hold(reason)
      raise ArgumentError, "#{reason} is not a reason to hold" unless HOLD.include?(reason)

      { reason: reason.to_s, message: MESSAGES.fetch(reason) }
    end
  end
end

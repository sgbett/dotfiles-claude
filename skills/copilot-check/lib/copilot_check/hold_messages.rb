# frozen_string_literal: true

module CopilotCheck
  module Reasons
    # Each message for a reason promote-check's verdict holds a draft for
    # (HOLD), keyed by the reason.
    HOLD_MESSAGES = {
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
      from_fork: "The pull request comes from a fork the authenticated user doesn't own.",
      files_unlisted: "The pull request's changed files could not all be listed, as GitHub lists at most 3,000, so " \
                      'changes to workflows or rules files cannot be ruled out.',
      protected_paths_changed: 'The pull request changes a path under .github/workflows/ or .github/actions/, ' \
                               "Copilot's rubric .github/copilot-instructions.md or a path under " \
                               '.github/instructions/, a file named CLAUDE.md, CLAUDE.local.md, .mcp.json, ' \
                               'AGENTS.md, GEMINI.md or REVIEW.md, or a path under a .claude directory ' \
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

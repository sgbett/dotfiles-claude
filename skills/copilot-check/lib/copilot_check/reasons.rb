# frozen_string_literal: true

require_relative 'reason_messages'

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

# frozen_string_literal: true

require_relative 'reason_messages'

module Do
  # Every reason the do skill's scripts can stop or ask for, with its
  # message (reason_messages.rb), and every reason `record closes` can hold
  # an issue open for. A message is a constant, so no GitHub text can reach
  # one; whatever an answer needs travels beside it in validated fields.
  module Reasons
    NOT_AN_ISSUE = :not_an_issue
    HOST_NOT_LOGGED_IN = :host_not_logged_in
    NO_ORIGIN = :no_origin
    COMMENTS_TRUNCATED = :comments_truncated
    UNTRUSTED_AUTHOR_CRITERIA = :untrusted_author_criteria
    GATE_ADVISORY = :gate_advisory
    GATE_RECORD_MISSING = :gate_record_missing
    REMOTE_MISSING = :remote_missing
    HOST_MISMATCH = :host_mismatch
    REMOTE_UNRESOLVABLE = :remote_unresolvable
    PUSH_REMOTE_NOT_THIS_REPOSITORY = :push_remote_not_this_repository
    FORK_NOT_WRITABLE = :fork_not_writable
    PR_TARGET_NOT_THIS_REPOSITORY = :pr_target_not_this_repository
    BRANCH_IS_BASE_OR_DEFAULT = :branch_is_base_or_default
    BASE_MISSING = :base_missing
    CHECKED_OUT_PR = :checked_out_pr
    REMOTE_TIPS_DIFFER = :remote_tips_differ
    UNTRUSTED_PULL_REQUEST = :untrusted_pull_request
    LOCAL_BRANCH_UNPUSHED = :local_branch_unpushed
    SCRIPTS_UNREVIEWED = :scripts_unreviewed
    NO_LEDGER = :no_ledger
    BOX_MISSING = :box_missing
    BODY_CHANGED = :body_changed
    UNTRUSTED_ISSUE_AUTHOR = :untrusted_issue_author
    NOT_A_SUB_ISSUE = :not_a_sub_issue
    UNTRUSTED_SUB_ISSUE = :untrusted_sub_issue
    NO_SUCH_FINDING = :no_such_finding
    GATE_ANSWERED = :gate_answered
    GATE_UNANSWERED = :gate_unanswered
    GATE_LINE_MISSING = :gate_line_missing
    AMBIGUOUS_CHECKBOX = :ambiguous_checkbox

    PREFLIGHT_STOPS = [NOT_AN_ISSUE, HOST_NOT_LOGGED_IN, GATE_ADVISORY, REMOTE_MISSING, HOST_MISMATCH,
                       REMOTE_UNRESOLVABLE, PUSH_REMOTE_NOT_THIS_REPOSITORY, FORK_NOT_WRITABLE,
                       PR_TARGET_NOT_THIS_REPOSITORY, BRANCH_IS_BASE_OR_DEFAULT, BASE_MISSING, CHECKED_OUT_PR,
                       REMOTE_TIPS_DIFFER, UNTRUSTED_PULL_REQUEST].freeze
    PREFLIGHT_ASKS = [NO_ORIGIN, COMMENTS_TRUNCATED, UNTRUSTED_AUTHOR_CRITERIA, GATE_RECORD_MISSING,
                      LOCAL_BRANCH_UNPUSHED, SCRIPTS_UNREVIEWED].freeze
    PREFLIGHT = (PREFLIGHT_STOPS + PREFLIGHT_ASKS).freeze
    # record finds its issue as pre-flight does (IssueLocator), so it shares
    # host_not_logged_in and no_origin, and examines its own checkout as
    # check does.
    RECORD_STOPS = [NOT_AN_ISSUE, HOST_NOT_LOGGED_IN, NO_LEDGER, BOX_MISSING, BODY_CHANGED, UNTRUSTED_ISSUE_AUTHOR,
                    NOT_A_SUB_ISSUE, UNTRUSTED_SUB_ISSUE, NO_SUCH_FINDING, GATE_ADVISORY, GATE_ANSWERED,
                    GATE_LINE_MISSING, AMBIGUOUS_CHECKBOX].freeze
    RECORD_ASKS = [NO_ORIGIN, GATE_UNANSWERED, SCRIPTS_UNREVIEWED].freeze
    RECORD = (RECORD_STOPS + RECORD_ASKS).freeze
    ALL = (PREFLIGHT | RECORD).freeze

    # Why `record closes` leaves an issue open: QA hasn't verified every box
    # in the issue body, or (when they hold its criteria) every ledger item,
    # or this sub-issue's ledger box; a sub-issue in another repository is
    # open, or its author isn't trusted; a sub-issue here has no ledger box.
    HELD = %i[unverified_boxes unverified_items open_elsewhere untrusted_elsewhere not_in_ledger].freeze

    module_function

    def not_an_issue(why)
      SkillSupport::Outcome.stop(NOT_AN_ISSUE, NOT_AN_ISSUE_MESSAGES.fetch(why))
    end

    def stop(reason, **fields)
      SkillSupport::Outcome.stop(reason, MESSAGES.fetch(reason), **fields)
    end

    # One entry of an ask's list; +details+ carries what the answer needs.
    def ask(reason, **details)
      { reason: reason, message: MESSAGES.fetch(reason), **details }
    end
  end
end

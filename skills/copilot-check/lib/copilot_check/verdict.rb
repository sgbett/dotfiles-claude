# frozen_string_literal: true

module CopilotCheck
  # Whether a converged draft may be marked ready: SKILL.md Phase 6's
  # conditions, every one evaluated, each that fails a HOLD reason
  # (Reasons::HOLD) in Phase 6's order. With none failing, PROMOTE.
  class Verdict
    PROMOTE = 'PROMOTE'
    HOLD = 'HOLD'
    CONVERGED = 'converged'
    OPEN = 'OPEN'
    MERGEABLE = 'MERGEABLE'
    PENDING = 'pending'
    CANCELLED = 'cancel'

    # +rules+ a PromotionRules; +started_as_draft+ whether the pull request
    # was a draft when the run began; +outcome+ the run's; +pull_request+ a
    # PullRequestQuery::PullRequest, with +mergeable+ re-read once if it was
    # UNKNOWN; +local_head+ the checkout's HEAD; +threads+ a fresh
    # Threads::Result, of which the reviews in +reviews_without_findings+
    # (ids) the run read and found no finding in; +files+ a
    # ChangedFiles::Result; +checks+ the Checks::Checks on the head.
    Facts = Struct.new(:rules, :started_as_draft, :outcome, :pull_request, :mergeable, :local_head, :threads,
                       :reviews_without_findings, :files, :checks, keyword_init: true)

    attr_reader :facts

    def initialize(facts)
      @facts = facts
    end

    def verdict
      reasons.empty? ? PROMOTE : HOLD
    end

    def reasons
      @reasons ||= [*pull_request_reasons, *rules_reasons, *run_reasons, *author_reasons, *files_reasons,
                    *checks_reasons, *merge_reasons].freeze
    end

    private

    def pull_request_reasons
      [(:not_open unless pull_request.state == OPEN), (:not_a_draft unless pull_request.draft)].compact
    end

    def rules_reasons
      [(:no_draft_flow unless @facts.rules.draft_flow?),
       (:merge_not_owners_step unless @facts.rules.merge_is_owners_step?),
       (:not_draft_at_start unless @facts.started_as_draft)].compact
    end

    def run_reasons
      threads = @facts.threads
      [(:not_converged unless @facts.outcome == CONVERGED),
       (:local_head_differs unless @facts.local_head == pull_request.head),
       (:copilot_not_on_head unless threads.latest_review&.commit == pull_request.head),
       (:todo_threads unless threads.todo_threads.empty?),
       (:unanswered_reviews unless unjudged_reviews.empty?)].compact
    end

    def author_reasons
      [(:not_viewers_own unless !pull_request.author.nil? && pull_request.author == pull_request.viewer),
       (:from_fork if pull_request.cross_repository)].compact
    end

    def files_reasons
      [(:files_unlisted unless @facts.files.complete),
       (:protected_paths_changed unless @facts.files.protected_paths.empty?)].compact
    end

    def checks_reasons
      checks = @facts.checks
      [(:no_checks if checks.empty?), (:checks_pending if bucket?(PENDING)), (:checks_cancelled if bucket?(CANCELLED)),
       (:undocumented_failures if checks.any? { |check| check.failed? && !check.documented })].compact
    end

    def bucket?(bucket)
      @facts.checks.any? { |check| check.bucket == bucket }
    end

    def merge_reasons
      [(:not_mergeable unless @facts.mergeable == MERGEABLE), (:auto_merge_on if pull_request.auto_merge)].compact
    end

    # The to-do reviews the run didn't find free of findings.
    def unjudged_reviews
      @facts.threads.todo_reviews.map(&:review_id) - @facts.reviews_without_findings
    end

    def pull_request
      @facts.pull_request
    end
  end
end

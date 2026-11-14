# frozen_string_literal: true

require_relative 'reasons'

module CopilotCheck
  # The fields of `promote-check check` output, in the order the lead reads
  # them: the verdict and every reason it holds for, then the facts the
  # lead's report and next calls need. Check names and changed paths, being
  # GitHub text, sit only under "github_text"; no body is printed.
  class GateReport
    # More protected paths than this are counted, not listed.
    LISTED_PATHS = 10

    def self.repository_fields(repository)
      { host: repository.host, name_with_owner: repository.name_with_owner }
    end

    # +repository+ is the CheckoutRepository::Repository; +number+ the pull
    # request's; +verdict+ the Verdict, whose Facts give the rest.
    def initialize(repository:, number:, verdict:)
      @repository = repository
      @number = number
      @verdict = verdict
      @facts = verdict.facts
    end

    def fields
      { verdict: @verdict.verdict, reasons: @verdict.reasons.map { |reason| Reasons.hold(reason) },
        repository: self.class.repository_fields(@repository), pull_request: pull_request,
        local_head: @facts.local_head, copilot: copilot, files: files, checks: checks }
    end

    private

    def pull_request
      pull_request = @facts.pull_request
      { number: @number, head: pull_request.head, is_draft: pull_request.draft, state: pull_request.state,
        mergeable: @facts.mergeable }
    end

    def copilot
      threads = @facts.threads
      { reviewed_commit: threads.latest_review&.commit, todo_threads: threads.todo_threads.length,
        todo_reviews: threads.todo_reviews.map(&:review_id) }
    end

    def files
      protected_paths = @facts.files.protected_paths
      { complete: @facts.files.complete, protected_paths: protected_paths.length,
        github_text: { protected_paths: protected_paths.first(LISTED_PATHS) } }
    end

    def checks
      @facts.checks.map do |check|
        { bucket: check.bucket, documented: check.documented, github_text: { name: check.name } }.compact
      end
    end
  end
end

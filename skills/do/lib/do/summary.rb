# frozen_string_literal: true

module Do
  # The facts pre-flight step 8's one-line summary needs, as short strings:
  # the issue, any untrusted author (the issue's or its parent's), the
  # parent, the resume point, open gate findings, and ignored marker
  # comments and skipped sub-issues with their authors. It names no
  # repository that may not be named on GitHub.
  class Summary
    DELETED_ACCOUNT = 'a deleted account'
    NOT_NAMEABLE = "an issue in a repository that isn't public"

    def initialize(assessment)
      @assessment = assessment
      @query = assessment.query
    end

    def fields
      { issue: "#{@query.repository.name_with_owner}##{@query.issue.number}",
        untrusted_authors: untrusted_authors, parent: @query.parent && named(@query.parent),
        resume_point: @assessment.ledger&.first_unbuilt&.id, open_gate_findings: @assessment.gate.open,
        ignored_markers: ignored_markers, skipped_sub_issues: skipped_sub_issues }
    end

    private

    def untrusted_authors
      @assessment.untrusted_authors.map do |who|
        "#{who} by #{login((who == :issue ? @query.issue : @query.parent).author)}"
      end
    end

    def ignored_markers
      @assessment.ignored_markers.map { |comment| "#{login(comment.author)} (comment #{comment.database_id})" }
    end

    # Pre-flight step 7 seeds a ledger only from trusted sub-issues it may
    # name.
    def skipped_sub_issues
      @query.sub_issues.reject { |sub_issue| @assessment.seedable?(sub_issue) }.map do |sub_issue|
        next NOT_NAMEABLE unless @assessment.nameable?(sub_issue)

        "#{named(sub_issue)} by #{login(sub_issue.author)} (#{@assessment.trust.issue(sub_issue).reason})"
      end
    end

    def named(record)
      @assessment.nameable?(record) ? @assessment.reference(record) : NOT_NAMEABLE
    end

    def login(author)
      author.login || DELETED_ACCOUNT
    end
  end
end

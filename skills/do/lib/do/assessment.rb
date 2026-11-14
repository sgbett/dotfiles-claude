# frozen_string_literal: true

require 'forwardable'
require_relative 'issue_view'
require_relative 'reasons'
require_relative 'reference_files'

module Do
  # What pre-flight makes of one issue's facts: the IssueView's reading of
  # them under /do's rules, where the security gate stands, and so whether
  # to stop, ask or go on.
  class Assessment
    extend Forwardable

    def_delegators :@view, :query, :trust, :ledger, :ignored_markers, :nameable?, :here?, :reference,
                   :untrusted_authors

    attr_reader :gate

    # +query+ is IssueQuery's Result for an issue, +gate_file+ the issue's
    # GateFile.
    def initialize(query, gate_file)
      @view = IssueView.new(query)
      @gate = gate_file.status(ledger ? ledger.gates : [])
    end

    def stop_reason
      Reasons::GATE_ADVISORY unless gate.advisory.empty?
    end

    # The ask entries that apply, in the order the lead should put them.
    def asks
      [comments_truncated, untrusted_author_criteria, gate_record_missing].compact
    end

    def read
      ReferenceFiles.applicable(resuming: resuming?, other_repositories: other_repositories?,
                                open_gate: !gate.open.empty?)
    end

    # Linked sub-issues a ledger may be seeded from: trusted and nameable.
    def seedable?(sub_issue)
      trust.issue(sub_issue).trusted && nameable?(sub_issue)
    end

    private

    # A trusted ledger among the first 100 comments is the earliest there
    # is; without one, it may be on a later page.
    def comments_truncated
      Reasons.ask(Reasons::COMMENTS_TRUNCATED) unless query.comments_complete || ledger
    end

    def untrusted_author_criteria
      untrusted = untrusted_authors
      return if untrusted.empty? || ledger&.adopted_criteria?

      Reasons.ask(Reasons::UNTRUSTED_AUTHOR_CRITERIA, authors: untrusted.map(&:to_s))
    end

    def gate_record_missing
      Reasons.ask(Reasons::GATE_RECORD_MISSING, findings: gate.missing) unless gate.missing.empty?
    end

    # Pre-flight step 7: a ledger, or trusted work in flight to seed one from.
    def resuming?
      !ledger.nil? || !query.branches.empty? || query.sub_issues.any? { |sub_issue| seedable?(sub_issue) }
    end

    def other_repositories?
      [query.parent, *query.sub_issues].compact.any? { |record| !here?(record) }
    end
  end
end

# frozen_string_literal: true

require_relative 'ledger'
require_relative 'reasons'
require_relative 'reference_files'
require_relative 'trust'
require_relative 'visibility'

module Do
  # What pre-flight makes of one issue's facts under /do's rules: who is
  # trusted, what may be named, which comment is the ledger, where the
  # security gate stands, and so whether to stop, ask or go on.
  class Assessment
    attr_reader :query, :trust, :ledger, :ignored_markers, :gate

    # +query+ is IssueQuery's Result for an issue, +gate_file+ the issue's
    # GateFile.
    def initialize(query, gate_file)
      @query = query
      @trust = Trust.new(viewer: query.viewer, home: query.repository)
      @ledger, @ignored_markers = locate_ledger
      @gate = gate_file.status(ledger ? ledger.gates : [])
    end

    # The issue's parent or one of its sub-issues: may GitHub text name it?
    def nameable?(record)
      Visibility.nameable?(record.repository, query.repository)
    end

    def here?(record)
      record.repository.same_as?(query.repository)
    end

    # "#M" for an issue here, "owner/repo#M" for one elsewhere.
    def reference(record)
      here?(record) ? "##{record.number}" : "#{record.repository.name_with_owner}##{record.number}"
    end

    # :issue and :parent when their authors aren't trusted.
    def untrusted_authors
      untrusted = []
      untrusted << :issue unless trust.here(query.issue.author).trusted
      untrusted << :parent if query.parent && !trust.issue(query.parent).trusted
      untrusted
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

    def locate_ledger
      comment, ignored = Ledger.locate(query.comments) { |marker| trust.here(marker.author).trusted }
      [comment && Ledger.new(comment, sub_issues: query.sub_issues, home: query.repository), ignored]
    end

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

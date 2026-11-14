# frozen_string_literal: true

require_relative 'ledger'
require_relative 'trust'
require_relative 'visibility'

module Do
  # One issue's facts as /do's rules read them, for every script: who is
  # trusted, what GitHub text may name, and which comment is the ledger.
  class IssueView
    attr_reader :query, :trust, :ledger, :ignored_markers

    # +query+ is IssueQuery's Result for an issue.
    def initialize(query)
      @query = query
      @trust = Trust.new(viewer: query.viewer, home: query.repository)
      @ledger, @ignored_markers = locate_ledger
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

    private

    def locate_ledger
      comment, ignored = Ledger.locate(query.comments) { |marker| trust.here(marker.author).trusted }
      [comment && Ledger.new(comment, sub_issues: query.sub_issues, home: query.repository), ignored]
    end
  end
end

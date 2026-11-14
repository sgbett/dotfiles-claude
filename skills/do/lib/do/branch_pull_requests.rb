# frozen_string_literal: true

module Do
  # The pull requests open on the branch, each with its author's trust: those
  # into this repository whose head is a branch of that name in a repository
  # the push remote pushes to, or in one GitHub no longer names (a deleted
  # fork), which can't be shown to be elsewhere. One by an untrusted author
  # is never adopted.
  class BranchPullRequests
    Entry = Struct.new(:pull_request, :verdict, keyword_init: true)

    # +pull_requests+ are CheckQuery's; +push_repositories+ the repositories
    # the push remote's URLs resolved to; +trust+ the Trust rule for this
    # repository, where these pull requests were written.
    def initialize(pull_requests, push_repositories:, trust:)
      on_branch = pull_requests.select { |pull_request| on_branch?(pull_request, push_repositories) }
      @entries = on_branch.map do |pull_request|
        Entry.new(pull_request: pull_request, verdict: trust.here(pull_request.author))
      end
    end

    def untrusted?
      @entries.any? { |entry| !entry.verdict.trusted }
    end

    def to_a
      @entries.map do |entry|
        { number: entry.pull_request.number, author: entry.pull_request.author.login, trusted: entry.verdict.trusted,
          trust_reason: entry.verdict.reason }
      end
    end

    private

    def on_branch?(pull_request, push_repositories)
      head = pull_request.head_repository
      head.nil? || push_repositories.any? { |repository| repository.casecmp?(head) }
    end
  end
end

# frozen_string_literal: true

require_relative 'body_edit'
require_relative 'checkout'
require_relative 'gate_file'
require_relative 'issue_locator'
require_relative 'issue_query'
require_relative 'issue_view'
require_relative 'reasons'

module Do
  # The issue a `record` subcommand acts on: located and fetched as
  # pre-flight's facts are, read under the same rules, with the bodies and
  # the gate file record edits.
  class RecordIssue
    # Visibilities where what is pushed isn't public, so the owner needn't
    # choose between a fix in the open and a private security advisory.
    NOT_PUBLIC = %w[PRIVATE INTERNAL].freeze

    attr_reader :view

    # Yields the RecordIssue for +argument+, the issue as the user gave it,
    # and returns what the block returns; or returns the stop or ask that
    # comes first, as pre-flight would.
    def self.locate(argument, runner:)
      IssueLocator.new(runner).locate(argument) do |reference|
        github = SkillSupport::Gh.new(host: reference.host, runner: runner)
        result = IssueQuery.new(github).fetch(reference.repository, reference.number)
        next Reasons.not_an_issue(result.kind) unless result.kind == :issue

        yield new(IssueView.new(result), github: github, runner: runner)
      end
    end

    def initialize(view, github:, runner:)
      @view = view
      @github = github
      @runner = runner
    end

    def ledger
      view.ledger
    end

    def issue
      view.query.issue
    end

    def issue_author_trusted?
      view.trust.here(issue.author).trusted
    end

    # Whether the issue body holds its acceptance criteria: not when its
    # author or its parent's isn't trusted, as those adopted instead live in
    # the ledger.
    def criteria_in_body?
      view.untrusted_authors.empty?
    end

    # Whether a gate finding needs the owner's answer before the ledger
    # names it: on a public repository, or one whose visibility GitHub
    # didn't give.
    def answer_required?
      !NOT_PUBLIC.include?(view.query.repository.visibility)
    end

    # The issue's sub-issue in this repository numbered +number+, or nil.
    def sub_issue_here(number)
      view.query.sub_issues.find { |sub_issue| sub_issue.number == number && view.here?(sub_issue) }
    end

    def issue_body
      BodyEdit.issue(@github, repository, issue.number)
    end

    def ledger_body
      BodyEdit.comment(@github, repository, ledger.comment.database_id)
    end

    # The ledger as +body+ would make it, to check a change before it's
    # written.
    def ledger_with(body)
      comment = ledger.comment
      Ledger.new(Comment.new(id: comment.id, database_id: comment.database_id, author: comment.author, body: body),
                 sub_issues: view.query.sub_issues, home: view.query.repository)
    end

    def gate_path
      GateFile.path(Checkout.new(@runner).common_directory, issue.id)
    end

    private

    def repository
      view.query.repository.name_with_owner
    end
  end
end

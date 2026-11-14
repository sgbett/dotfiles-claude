# frozen_string_literal: true

require_relative 'body_edit'
require_relative 'checklist'
require_relative 'checkout'
require_relative 'gate_file'
require_relative 'issue_locator'
require_relative 'issue_query'
require_relative 'issue_view'
require_relative 'reasons'
require_relative 'record_lock'

module Do
  # The issue a `record` subcommand acts on: located and fetched as
  # pre-flight's facts are, read under the same rules, with the bodies and
  # the gate file record edits. A call that writes holds the issue's
  # RecordLock from the moment the issue's node id, which names the lock, is
  # known; one that only reads takes none, so creates no lock file.
  class RecordIssue
    # Visibilities where what is pushed isn't public, so the owner needn't
    # choose between a fix in the open and a private security advisory.
    NOT_PUBLIC = %w[PRIVATE INTERNAL].freeze

    attr_reader :view

    # Yields the RecordIssue for +argument+, the issue as the user gave it,
    # with its lock held if the call +writes+, and returns what the block
    # returns; or returns the stop or ask that comes first, as pre-flight
    # would.
    def self.locate(argument, runner:, writes:, &block)
      IssueLocator.new(runner).locate(argument) do |reference|
        github = SkillSupport::Gh.new(host: reference.host, runner: runner)
        result = IssueQuery.new(github).fetch(reference.repository, reference.number)
        next Reasons.not_an_issue(result.kind) unless result.kind == :issue

        open_issue(result, github, Checkout.new(runner).common_directory, writes: writes, &block)
      end
    end

    # Yields the RecordIssue for +result+, IssueQuery's Result for an issue,
    # with the issue's lock held if the call +writes+.
    def self.open_issue(result, github, common_directory, writes:)
      issue = new(IssueView.new(result), github: github, common_directory: common_directory)
      return yield issue unless writes

      RecordLock.hold(RecordLock.path(common_directory, result.issue.id)) { yield issue }
    end

    private_class_method :open_issue

    def initialize(view, github:, common_directory:)
      @view = view
      @github = github
      @common_directory = common_directory
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

    # The issue body as it reads now, and Checklist's Reading of it.
    def issue_reading
      text = issue_body.read
      [text, Checklist.scan(text, target: :issue_body)]
    end

    # The issue body as it reads now, and its Checklist boxes, to tick.
    # Raises BodyChanged when its boxes no longer have +digest+, facts'
    # issue.boxes_digest, as positions facts gave could then name other
    # boxes; and AmbiguousCheckbox when a line reads like a box Checklist
    # can't place.
    def issue_boxes(digest)
      text, reading = issue_reading
      raise BodyChanged unless reading.digest == digest
      raise AmbiguousCheckbox.new(:issue_body, reading.ambiguous) if reading.ambiguous?

      [text, reading.boxes]
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
      GateFile.path(@common_directory, issue.id)
    end

    private

    def repository
      view.query.repository.name_with_owner
    end
  end
end

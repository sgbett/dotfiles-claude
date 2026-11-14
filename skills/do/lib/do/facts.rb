# frozen_string_literal: true

require_relative 'assessment'
require_relative 'body_edit'
require_relative 'checklist'
require_relative 'checkout'
require_relative 'facts_report'
require_relative 'gate_file'
require_relative 'issue_locator'
require_relative 'issue_query'
require_relative 'issue_view'
require_relative 'reasons'
require_relative 'slug'

module Do
  # `preflight facts --argument-file <path>`, the read-only first half of
  # /do's pre-flight: gathers the issue's facts from GitHub and the
  # checkout, and stops, asks or proceeds with them. Lines that read like
  # boxes Checklist can't place are reported, never a stop: `record closes`
  # holds the issue open on them, and only the record calls that write
  # boxes stop.
  class Facts
    # +argument+ names the issue as the user gave it. Every gh and git call
    # goes through +runner+, in the working directory.
    def initialize(argument, runner: SkillSupport::CommandRunner.new)
      @argument = argument
      @runner = runner
      @checkout = Checkout.new(runner)
    end

    def call
      IssueLocator.new(@runner).locate(@argument) { |reference| facts(reference) }
    end

    private

    def facts(reference)
      github = SkillSupport::Gh.new(host: reference.host, runner: @runner)
      query = IssueQuery.new(github)
      result = query.fetch(reference.repository, reference.number)
      return Reasons.not_an_issue(result.kind) unless result.kind == :issue

      report(result, github, host: reference.host, parent_branches: parent_branches(query, result))
    end

    # The default base is the branch of a parent in this repository.
    def parent_branches(query, result)
      parent = result.parent
      return [] unless parent&.repository&.same_as?(result.repository)

      query.branch_names(result.repository.name_with_owner, parent.number)
    end

    def report(result, github, host:, parent_branches:)
      gate_path = GateFile.path(@checkout.common_directory, result.issue.id)
      default_branch = Slug.default_branch(result.issue.number, result.issue.title, runner: @runner)
      view = IssueView.new(result)
      assessment = Assessment.new(view, GateFile.read(gate_path), issue_boxes: issue_boxes(github, view))
      fields = FactsReport.new(assessment, host: host, gate_path: gate_path, parent_branches: parent_branches,
                                           default_branch: default_branch).fields
      outcome(assessment, fields)
    end

    # The issue body's Checklist::Reading, whose boxes the lead maps QA's
    # verified boxes to, where they hold the acceptance criteria: when the
    # issue's author and its parent's are trusted.
    def issue_boxes(github, view)
      return unless view.untrusted_authors.empty?

      body = BodyEdit.issue(github, view.query.repository.name_with_owner, view.query.issue.number).read
      Checklist.scan(body, target: :issue_body)
    end

    def outcome(assessment, fields)
      return Reasons.stop(assessment.stop_reason, **fields) if assessment.stop_reason

      asks = assessment.asks
      asks.empty? ? SkillSupport::Outcome.proceed(**fields) : SkillSupport::Outcome.ask(asks, **fields)
    end
  end
end

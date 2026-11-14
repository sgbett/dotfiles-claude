# frozen_string_literal: true

require_relative 'branch_names'
require_relative 'issue_reference'
require_relative 'slug'
require_relative 'summary'

module Do
  # The fields of `preflight facts` output, in the order the lead reads
  # them. GitHub text (titles, label names, the start of each box's text)
  # sits only under "github_text" keys, beside its author's trust where it
  # has one. Whatever may not go on GitHub, such as an issue in a repository
  # that isn't public or a local path, sits only under "session_only". No
  # body is printed.
  class FactsReport
    # +assessment+ is the issue's Assessment; +parent_branches+ the names of
    # the parent's feat/<N>-* branches when it lives here.
    def initialize(assessment, host:, gate_path:, parent_branches:, default_branch:)
      @assessment = assessment
      @query = assessment.query
      @host = host
      @gate_path = gate_path
      @parent_branches = parent_branches
      @default_branch = default_branch
    end

    def fields
      { reference: reference, summary: Summary.new(@assessment).fields, repository: repository, issue: issue,
        parent: parent, sub_issues: sub_issues, ledger: ledger, ignored_markers: ignored_markers,
        gate: @assessment.gate.to_h, branches: branches, parent_branches: parent_branches, slug: slug,
        default_branch: @default_branch, read: @assessment.read, session_only: session_only }
    end

    private

    # What every later call takes in place of the reference the user gave,
    # in the repository's name as GitHub gives it now.
    def reference
      IssueReference.canonical(@host, @query.repository.name_with_owner, @query.issue.number)
    end

    # Labels are never a trust input, so a cut-off list is said, not fatal.
    def repository
      { id: @query.repository_id, name_with_owner: @query.repository.name_with_owner, host: @host,
        owner: @query.repository.owner, visibility: @query.repository.visibility,
        default_branch_ref: (@query.default_branch_ref if BranchNames.usable?(@query.default_branch_ref)),
        labels: @query.labels.map { |label| { id: label.id, github_text: { name: label.name } } },
        labels_truncated: !@query.labels_complete }
    end

    def issue
      issue = @query.issue
      { id: issue.id, number: issue.number, state: issue.state, author: issue.author.login,
        **trust(@assessment.trust.here(issue.author)), project_items: @query.project_items, boxes: boxes,
        github_text: { title: issue.title } }
    end

    # The body's boxes, when they hold the acceptance criteria.
    def boxes
      @assessment.boxes&.map { |box| { **box.to_h.slice(:position, :checked), github_text: { label: box.label } } }
    end

    def parent
      @query.parent && related(@query.parent)
    end

    def sub_issues
      @query.sub_issues.map { |sub_issue| related(sub_issue) }
    end

    # The parent or a sub-issue. One that may not be named leaves its
    # reference and title to session_only.
    def related(record)
      nameable = @assessment.nameable?(record)
      fields = { id: record.id, reference: (@assessment.reference(record) if nameable),
                 same_repository: @assessment.here?(record), nameable: nameable, state: record.state,
                 author: record.author.login, **trust(@assessment.trust.issue(record)) }
      nameable ? fields.merge(github_text: { title: record.title }) : fields
    end

    def ledger
      ledger = @assessment.ledger
      return unless ledger

      ledger_comment(ledger.comment).merge(
        items: ledger.items.map { |item| ledger_item(item) },
        gates: ledger.gates.map { |gate| { id: gate.id, state: gate.state } },
        first_unbuilt: ledger.first_unbuilt&.id, adopted_criteria: ledger.adopted_criteria?
      )
    end

    # comment_id is the REST id a later edit of the ledger goes through.
    def ledger_comment(comment)
      { comment_id: SkillSupport::Identifiers.comment_id!(comment.database_id), node_id: comment.id,
        author: comment.author.login }
    end

    def ledger_item(item)
      fields = { id: item.id, position: item.position, kind: item.kind, checked: item.checked }
      item.sub_issue ? fields.merge(sub_issue: item.sub_issue.id, state: item.sub_issue.state) : fields
    end

    def ignored_markers
      @assessment.ignored_markers.map do |comment|
        { comment_id: comment.database_id, author: comment.author.login,
          trust_reason: @assessment.trust.here(comment.author).reason }
      end
    end

    def branches
      @query.branches.select { |branch| BranchNames.usable?(branch.name) }.map do |branch|
        { name: branch.name, pull_requests: branch.pull_requests.map { |pull_request| pull_request(pull_request) } }
      end
    end

    def parent_branches
      BranchNames.usable(@parent_branches)
    end

    def slug
      Slug.from_title(@query.issue.title)
    end

    def pull_request(pull_request)
      { number: pull_request.number, author: pull_request.author.login,
        **trust(@assessment.trust.here(pull_request.author)) }
    end

    def session_only
      unnamed = [@query.parent, *@query.sub_issues].compact.reject { |record| @assessment.nameable?(record) }
      { gate_file: @gate_path,
        not_nameable: unnamed.map do |record|
          { id: record.id, reference: @assessment.reference(record), github_text: { title: record.title } }
        end,
        unusable_branches: unusable_branches }
    end

    # The default branch's name, this issue's branches' and the parent's.
    def unusable_branches
      BranchNames.unusable([@query.default_branch_ref, *@query.branches.map(&:name), *@parent_branches])
    end

    def trust(verdict)
      { trusted: verdict.trusted, trust_reason: verdict.reason }
    end
  end
end

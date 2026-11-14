# frozen_string_literal: true

require_relative 'result_mapping'
require_relative 'slug'

module Do
  # The GraphQL behind `preflight facts`: one query for the viewer, the
  # issue's repository, the issue with its parent, sub-issues and comments,
  # and the branches in flight for it, and a follow-up for a parent's
  # branches. Values travel as variables, never in the query text.
  class IssueQuery
    QUERY = File.read(File.join(__dir__, 'issue.graphql'))
    BRANCHES_QUERY = File.read(File.join(__dir__, 'branches.graphql'))
    # Where GitHub's NOT_FOUND errors point when the repository, or the
    # number within it, names nothing the viewer can see.
    MISSING = { %w[repository] => :missing_repository, %w[repository issueOrPullRequest] => :missing_issue }.freeze
    NOT_FOUND = 'NOT_FOUND'

    # +kind+ is :issue, :pull_request, :missing_issue, :missing_repository,
    # or :moved when the issue now lives in another repository; only an
    # :issue carries the rest. +comments_complete+ is false when the issue
    # has more comments than the page that came back.
    Result = Struct.new(:kind, :viewer, :repository, :repository_id, :default_branch_ref, :labels, :issue, :parent,
                        :sub_issues, :project_items, :comments, :comments_complete, :branches, keyword_init: true)

    def self.variables(repository, number)
      owner, name = SkillSupport::Identifiers.repository!(repository).split('/')
      { 'owner' => owner, 'name' => name, 'number' => number, 'branchQuery' => Slug.branch_prefix(number) }
    end

    def self.branches_variables(repository, number)
      variables(repository, number).except('number')
    end

    # :missing_repository or :missing_issue when +errors+ are GitHub's
    # NOT_FOUND for the repository, or for the number within it, and nothing
    # else; nil for any other errors.
    def self.missing_kind(errors)
      kinds = Array(errors).map { |error| error.is_a?(Hash) && error['type'] == NOT_FOUND && MISSING[error['path']] }
      kinds.first if kinds.uniq.length == 1
    end

    # +github+ is the SkillSupport::Gh for the issue's host.
    def initialize(github)
      @github = github
    end

    # What issue +number+ of +repository+ ("owner/repo") is, as a Result.
    # Raises IncompleteResults when the labels, the sub-issues, the branches
    # or their pull requests overflow a page.
    def fetch(repository, number)
      data = @github.graphql(QUERY, self.class.variables(repository, number))
      ResultMapping.new(data).result
    rescue SkillSupport::GraphqlError => e
      kind = self.class.missing_kind(e.errors)
      raise unless kind

      Result.new(kind: kind)
    end

    # The names of +repository+'s branches for issue +number+, feat/<N>-*.
    def branch_names(repository, number)
      data = @github.graphql(BRANCHES_QUERY, self.class.branches_variables(repository, number))
      refs = SkillSupport::Pagination.ensure_complete!(data, 'repository', 'refs')
      refs['nodes'].map { |ref| ref['name'] }.select { |name| name.start_with?(Slug.branch_prefix(number)) }
    end
  end
end

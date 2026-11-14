# frozen_string_literal: true

require_relative 'issue_query'
require_relative 'records'

module Do
  # The GraphQL behind `preflight check`, one query to a step so that each
  # runs only once the steps before it have passed: the issue's repository
  # as GitHub names it now, with its default branch, whether the base branch
  # exists, and the pull requests open on the branch. Values travel as
  # variables.
  class CheckQuery
    ISSUE_QUERY = File.read(File.join(__dir__, 'issue_repository.graphql'))
    BASE_QUERY = File.read(File.join(__dir__, 'base_branch.graphql'))
    PULL_REQUESTS_QUERY = File.read(File.join(__dir__, 'pull_requests.graphql'))

    # +kind+ is :issue, :pull_request, :missing_issue, :missing_repository or
    # :moved; only an :issue carries the viewer's login, +repository+, the
    # repository's nameWithOwner as GitHub gives it, after any rename, and
    # +default_branch+, nil for a repository with no commits.
    Issue = Struct.new(:kind, :viewer, :repository, :default_branch, keyword_init: true)

    def self.issue_variables(repository, number)
      repository_variables(repository).merge('number' => number)
    end

    def self.base_variables(repository, base)
      repository_variables(repository).merge('qualifiedName' => "refs/heads/#{base}")
    end

    def self.pull_request_variables(repository, branch)
      repository_variables(repository).merge('branch' => branch)
    end

    def self.repository_variables(repository)
      owner, name = SkillSupport::Identifiers.repository!(repository).split('/')
      { 'owner' => owner, 'name' => name }
    end

    # +github+ is the SkillSupport::Gh for the issue's host.
    def initialize(github)
      @github = github
    end

    # What issue +number+ of +repository+ ("owner/repo") is, as an Issue.
    def issue(repository, number)
      data = @github.graphql(ISSUE_QUERY, self.class.issue_variables(repository, number))
      home = canonical_name(data['repository'])
      Issue.new(kind: kind(data.dig('repository', 'issueOrPullRequest'), home), viewer: data.dig('viewer', 'login'),
                repository: home, default_branch: data.dig('repository', 'defaultBranchRef', 'name'))
    rescue SkillSupport::GraphqlError => e
      kind = IssueQuery.missing_kind(e.errors)
      raise unless kind

      Issue.new(kind: kind)
    end

    # The commit +repository+'s branch +base+ points to, or nil when it has
    # no such branch.
    def base_commit(repository, base)
      data = @github.graphql(BASE_QUERY, self.class.base_variables(repository, base))
      node = data['repository']
      raise SkillSupport::UnexpectedResponse, 'the base branch query returned no repository' unless node.is_a?(Hash)
      return if node['ref'].nil?

      SkillSupport::Identifiers.commit_sha!(node.dig('ref', 'target', 'oid'))
    end

    # The pull requests into +repository+ open from a branch named +branch+,
    # in any repository. Raises IncompleteResults when they overflow a page.
    def pull_requests(repository, branch)
      data = @github.graphql(PULL_REQUESTS_QUERY, self.class.pull_request_variables(repository, branch))
      SkillSupport::Pagination.ensure_complete!(data, 'repository', 'pullRequests').fetch('nodes').map do |node|
        PullRequest.new(number: node['number'], author: Author.from_node(node),
                        head_repository: node.dig('headRepository', 'nameWithOwner'))
      end
    end

    private

    def canonical_name(node)
      name = node['nameWithOwner'] if node.is_a?(Hash)
      raise SkillSupport::UnexpectedResponse, 'the issue query returned a nameless repository' unless name

      SkillSupport::Identifiers.repository!(name)
    end

    def kind(node, home)
      case node.is_a?(Hash) && node['__typename']
      when 'PullRequest' then :pull_request
      when 'Issue' then node.dig('repository', 'nameWithOwner').to_s.casecmp?(home) ? :issue : :moved
      else raise SkillSupport::UnexpectedResponse, 'the issue query returned neither an issue nor a pull request'
      end
    end
  end
end

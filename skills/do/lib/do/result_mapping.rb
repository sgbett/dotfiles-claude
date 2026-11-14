# frozen_string_literal: true

require_relative 'records'
require_relative 'slug'

module Do
  # Turns the data IssueQuery's GraphQL query returned into an
  # IssueQuery::Result of records. The sub-issues, branches and their pull
  # requests must have come back whole (IncompleteResults otherwise); for
  # labels, comments, editors and renamers it records whether they did, for
  # the caller to fail closed on or report.
  class ResultMapping
    def initialize(data)
      @data = data
      @repository = data['repository']
      raise SkillSupport::UnexpectedResponse, 'the issue query returned no repository' unless @repository.is_a?(Hash)

      @node = @repository['issueOrPullRequest']
    end

    def result
      case @node.is_a?(Hash) && @node['__typename']
      when 'PullRequest' then IssueQuery::Result.new(kind: :pull_request)
      when 'Issue' then issue_result
      else raise SkillSupport::UnexpectedResponse, 'the issue query returned neither an issue nor a pull request'
      end
    end

    private

    def issue_result
      home = repository(@repository)
      issue = issue_record(@node)
      return IssueQuery::Result.new(kind: :moved) unless issue.repository.same_as?(home)

      IssueQuery::Result.new(kind: :issue, issue: issue, **repository_facts(home), **issue_facts)
    end

    def repository_facts(home)
      { viewer: @data.dig('viewer', 'login'), repository: home, repository_id: @repository['id'],
        default_branch_ref: @repository.dig('defaultBranchRef', 'name'), labels: labels,
        labels_complete: complete?(@repository['labels']), branches: branches(home) }
    end

    def issue_facts
      { parent: @node['parent'] && issue_record(@node['parent']), sub_issues: sub_issues,
        project_items: @node.dig('projectItems', 'totalCount'), comments: comments,
        comments_complete: complete?(@node['comments']) }
    end

    def labels
      Array(@repository.dig('labels', 'nodes')).map { |label| Label.new(id: label['id'], name: label['name']) }
    end

    def sub_issues
      nodes(@node, 'subIssues').map { |sub_issue| issue_record(sub_issue) }
    end

    def comments
      Array(@node.dig('comments', 'nodes')).map do |comment|
        Comment.new(id: comment['id'], database_id: comment['databaseId'], author: author(comment),
                    body: comment['body'])
      end
    end

    # Only branches named for this issue: GitHub's ref query matches the
    # name anywhere, not just at the start.
    def branches(home)
      prefix = Slug.branch_prefix(@node['number'])
      nodes(@repository, 'refs').select { |ref| ref['name'].start_with?(prefix) }.map do |ref|
        Branch.new(name: ref['name'], pull_requests: pull_requests(ref, home))
      end
    end

    # Pull requests into this repository; a fork's branch can also head
    # one into its parent.
    def pull_requests(ref, home)
      nodes(ref, 'associatedPullRequests')
        .select { |pull_request| pull_request.dig('baseRepository', 'nameWithOwner')&.casecmp?(home.name_with_owner) }
        .map { |pull_request| PullRequest.new(number: pull_request['number'], author: author(pull_request)) }
    end

    def issue_record(node)
      unless node['id'].is_a?(String) && node['number'].is_a?(Integer)
        raise SkillSupport::UnexpectedResponse, 'the issue query returned an issue without its id or number'
      end

      IssueRecord.new(id: node['id'], number: node['number'], title: node['title'], state: node['state'],
                      author: author(node), repository: repository(node['repository']), edits: edits(node))
    end

    def repository(node)
      name = node.is_a?(Hash) ? node['nameWithOwner'] : nil
      owner = node.is_a?(Hash) ? node.dig('owner', 'login') : nil
      raise SkillSupport::UnexpectedResponse, 'the issue query returned a nameless repository' unless name && owner

      Repository.new(name_with_owner: name, owner: owner, visibility: node['visibility'])
    end

    def author(node)
      Author.from_node(node)
    end

    def edits(node)
      editors = node['userContentEdits']
      renamers = node['timelineItems']
      Edits.new(logins: logins(editors, 'editor') + logins(renamers, 'actor'),
                complete: complete?(editors) && complete?(renamers))
    end

    # A node without a login, a deleted account's or one of another type,
    # comes back as nil.
    def logins(connection, role)
      nodes = connection.is_a?(Hash) ? Array(connection['nodes']) : []
      nodes.map { |node| node.is_a?(Hash) ? node.dig(role, 'login') : nil }
    end

    def nodes(parent, connection)
      SkillSupport::Pagination.ensure_complete!(parent, connection).fetch('nodes')
    end

    def complete?(connection)
      SkillSupport::Pagination.ensure_complete!(connection)
      true
    rescue SkillSupport::IncompleteResults
      false
    end
  end
end

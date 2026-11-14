# frozen_string_literal: true

require_relative '../../lib/do/issue_query'

module Do
  module Testing
    # GraphQL answers to IssueQuery's query: the one recorded for
    # sgbett/dotfiles-claude#24, changed where a spec needs another case,
    # with synthesised example- repositories for anything it lacks.
    module IssueResponses
      GRAPHQL = %w[gh api graphql --hostname github.com --input -].freeze
      HERE = 'sgbett/dotfiles-claude'

      def recorded_repository
        HERE
      end

      def graphql_command
        GRAPHQL
      end

      # The recorded answer, its issue node and data handed to the block to
      # change.
      def issue_response
        response = JSON.parse(fixture('graphql/issue-24.json'))
        data = response.fetch('data')
        yield data.dig('repository', 'issueOrPullRequest'), data if block_given?
        response
      end

      def issue_request(repository = HERE, number = 24)
        JSON.generate('query' => Do::IssueQuery::QUERY, 'variables' => Do::IssueQuery.variables(repository, number))
      end

      # Expects IssueQuery's query on the fake runner, answered by +response+
      # (a recorded String or a Hash to send as JSON).
      def expect_issue_query(response, repository: HERE, number: 24, **result)
        stdout = response.is_a?(String) ? response : JSON.generate(response)
        fake_runner.expect_call(GRAPHQL, stdin: issue_request(repository, number), stdout: stdout, **result)
      end

      # Expects IssueQuery's branch query for issue +number+ of the recorded
      # repository, answered with branches named +names+.
      def expect_branches_query(number, names, more: false)
        request = { 'query' => Do::IssueQuery::BRANCHES_QUERY,
                    'variables' => { 'owner' => 'sgbett', 'name' => 'dotfiles-claude',
                                     'branchQuery' => "feat/#{number}-" } }
        answer = { 'data' => { 'repository' => { 'refs' => connection(names.map { |name| { 'name' => name } },
                                                                      more: more) } } }
        fake_runner.expect_call(GRAPHQL, stdin: JSON.generate(request), stdout: JSON.generate(answer))
      end

      def connection(nodes, more: false)
        { 'pageInfo' => { 'hasNextPage' => more, 'hasPreviousPage' => false }, 'nodes' => nodes }
      end

      # The author fields of a node; +login+ nil is a deleted account.
      def authored_by(login, association: 'OWNER', viewer: false)
        { 'author' => login && { 'login' => login }, 'authorAssociation' => association, 'viewerDidAuthor' => viewer }
      end

      def viewer_authored
        authored_by('sgbett', viewer: true)
      end

      # A parent or sub-issue node, edited by its author alone.
      def issue_node(number, repository, by: viewer_authored, visibility: 'PUBLIC')
        { 'id' => "I_example#{number}", 'number' => number, 'title' => "Example issue #{number}", 'state' => 'OPEN',
          **by, 'repository' => { 'nameWithOwner' => repository, 'visibility' => visibility,
                                  'owner' => { 'login' => repository.split('/').first } },
          'userContentEdits' => editors([by.dig('author', 'login')]), 'timelineItems' => connection([]) }
      end

      # A userContentEdits connection; nil is a deleted account.
      def editors(logins, more: false)
        connection(logins.map { |login| { 'editor' => login && { 'login' => login } } }, more: more)
      end

      def comment_node(body, database_id:, by: viewer_authored)
        { 'id' => "IC_example#{database_id}", 'databaseId' => database_id, **by, 'body' => body }
      end

      def ledger_body(issue)
        issue.dig('comments', 'nodes', 0, 'body')
      end
    end
  end
end

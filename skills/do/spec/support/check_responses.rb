# frozen_string_literal: true

require 'base64'

module Do
  module Testing
    # What the specs of `preflight check` answer its calls with, recorded from
    # sgbett/dotfiles-claude#24 or built here.
    module CheckResponses
      HERE = 'sgbett/dotfiles-claude'
      BRANCH = 'feat/24-hlr-do-and-copilot-check-move'
      ORIGIN_URL = 'https://github.com/sgbett/dotfiles-claude.git'
      BASE_SHA = '6b9895d961416bbb7561778aff4e651822796e9e'
      GRAPHQL = %w[gh api graphql --hostname github.com --input -].freeze

      # The contents API's answer for a file holding +text+.
      def contents_file(path, text)
        { 'name' => File.basename(path), 'path' => path, 'type' => 'file', 'encoding' => 'base64',
          'content' => Base64.encode64(text) }
      end

      # A pull request node; +login+ nil is a deleted account, +head+ nil a
      # head repository GitHub no longer names.
      def pull_request_node(number, login, association: 'OWNER', viewer: false, head: HERE)
        { 'number' => number, 'author' => login && { 'login' => login }, 'authorAssociation' => association,
          'viewerDidAuthor' => viewer, 'headRepository' => head && { 'nameWithOwner' => head } }
      end

      def pull_requests_response(nodes)
        { 'data' => { 'repository' => { 'pullRequests' => {
          'pageInfo' => { 'hasNextPage' => false, 'hasPreviousPage' => false }, 'nodes' => nodes
        } } } }
      end

      private

      def graphql_request(query, variables)
        JSON.generate('query' => query, 'variables' => variables)
      end

      def as_json(response)
        response.is_a?(String) ? response : JSON.generate(response)
      end

      def lines(values)
        values.map { |value| "#{value}\n" }.join
      end

      # A call answering +value+ on one line, or exiting 1 with nothing for nil.
      def expect_line(argv, value)
        fake_runner.expect_call(argv, stdout: value ? "#{value}\n" : '', exit_status: value ? 0 : 1)
      end
    end
  end
end

# frozen_string_literal: true

require_relative 'copilot'
require_relative 'reasons'
require_relative 'stop'
require_relative 'threads'
require_relative 'timestamp'

module CopilotCheck
  # When Copilot's latest review of a pull request came: Phase 0's
  # high-water mark, and what Phase 5's watcher polls, as a review lands
  # with all its comments at once. reviews(last: 1) sees the latest however
  # many reviews there are, where a REST list's first page goes stale as
  # every reply adds a review; author: only narrows by login, and the id is
  # the match.
  class LatestReview
    QUERY = File.read(File.join(__dir__, 'latest_review.graphql'))

    def self.variables(repository, number)
      Threads.variables(repository, number)
    end

    # +github+ is the SkillSupport::Gh for the repository's host.
    def initialize(github)
      @github = github
    end

    # The submittedAt of Copilot's latest review of pull request +number+ of
    # +repository+ ("owner/repo"), or nil when it has made none. Raises Stop
    # when that review, found by Copilot's login, carries another id.
    def submitted_at(repository, number)
      node = nodes(@github.graphql(QUERY, self.class.variables(repository, number))).first
      return unless node
      raise Stop, Reasons::COPILOT_ID_CHANGED unless Copilot.authored?(node)

      Timestamp.check!(node['submittedAt'], kind: :submitted_at)
    end

    private

    def nodes(data)
      nodes = data.dig('repository', 'pullRequest', 'reviews', 'nodes')
      return nodes if nodes.is_a?(Array) && nodes.all?(Hash)

      raise SkillSupport::UnexpectedResponse, "the latest review query returned no pull request's reviews"
    end
  end
end

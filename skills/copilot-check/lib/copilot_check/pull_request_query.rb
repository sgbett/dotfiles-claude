# frozen_string_literal: true

module CopilotCheck
  # A pull request as GitHub has it now, with the viewer: what Phase 6
  # re-reads, as the owner may have changed it mid-run.
  class PullRequestQuery
    QUERY = File.read(File.join(__dir__, 'pull_request.graphql'))
    FLAGS = %w[isDraft isCrossRepository].freeze

    # +state+ is OPEN, CLOSED or MERGED; +head+ the head commit's oid;
    # +mergeable+ MERGEABLE, CONFLICTING or UNKNOWN; +changed_files+ how many
    # files it changes; +author+ its author's login, nil for a deleted
    # account; +auto_merge+ whether auto-merge is on; +viewer+ the
    # authenticated user's login.
    PullRequest = Struct.new(:state, :draft, :cross_repository, :head, :mergeable, :changed_files, :author,
                             :auto_merge, :viewer, keyword_init: true)

    def self.variables(repository, number)
      owner, name = SkillSupport::Identifiers.repository!(repository).split('/')
      { 'owner' => owner, 'name' => name, 'number' => SkillSupport::Identifiers.issue_number!(number) }
    end

    # +github+ is the SkillSupport::Gh for the repository's host.
    def initialize(github)
      @github = github
    end

    # Pull request +number+ of +repository+ ("owner/repo"), as a PullRequest.
    def fetch(repository, number)
      data = @github.graphql(QUERY, self.class.variables(repository, number))
      node = data.dig('repository', 'pullRequest')
      raise SkillSupport::UnexpectedResponse, 'the pull request query returned no pull request' unless node.is_a?(Hash)

      record(node, data.dig('viewer', 'login'))
    end

    private

    def record(node, viewer)
      check_types(node)
      PullRequest.new(state: node['state'], draft: node['isDraft'], cross_repository: node['isCrossRepository'],
                      head: SkillSupport::Identifiers.commit_sha!(node['headRefOid']), mergeable: node['mergeable'],
                      changed_files: node['changedFiles'], author: node.dig('author', 'login'),
                      auto_merge: !node['autoMergeRequest'].nil?, viewer: viewer)
    end

    def check_types(node)
      flags = node.values_at(*FLAGS)
      return if flags.all? { |flag| [true, false].include?(flag) } && node['changedFiles'].is_a?(Integer)

      raise SkillSupport::UnexpectedResponse, 'the pull request query returned no isDraft, isCrossRepository or ' \
                                              'changedFiles'
    end
  end
end

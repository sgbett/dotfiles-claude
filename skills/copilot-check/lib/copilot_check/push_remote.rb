# frozen_string_literal: true

module CopilotCheck
  # Whether a push to a remote of the pull request's checkout goes to the
  # pull request's head repository alone, as Phase 5's push must: every URL
  # git pushes to for the remote, its pushurls or else its url, as git
  # rewrites them, must be on the repository's host and resolve, through
  # GitHub, to the head repository. Which repository a URL is comes from
  # GitHub, never the URL, as a URL can be an alias or a repository's old
  # name. A push that names its remote goes to that remote's URLs, never
  # remote.pushDefault's, so the remote alone is checked. As in /do's
  # PushRemote, every host is checked before gh is asked about any URL.
  class PushRemote
    VIEW_FIELDS = %w[nameWithOwner].freeze

    # +github+ is the SkillSupport::Gh for the repository's host.
    def initialize(runner, github)
      @git = SkillSupport::Git.new(runner)
      @github = github
    end

    # Whether every URL a push to +remote+ from the checkout at +top_level+
    # goes to is +repository+ ("owner/repo"), ignoring case as GitHub does.
    # Raises GhError when gh can't resolve a URL, as for one naming no
    # repository GitHub has, and InvalidIdentifier when its answer names no
    # repository.
    def pushes_only_to?(top_level, remote, repository)
      urls = push_urls(top_level, remote)
      return false if urls.empty? || !urls.all? { |url| SkillSupport::RemoteUrl.host(url) == @github.host }

      urls.all? { |url| resolve(url)&.casecmp?(repository) }
    end

    private

    # git gives a remote with no url its own name, which reads as a local
    # path.
    def push_urls(top_level, remote)
      @git.output('-C', top_level, 'remote', 'get-url', '--push', '--all', remote).lines(chomp: true).reject(&:empty?)
    end

    # The repository GitHub resolves +url+ to, or nil for a URL gh would
    # read as a local path rather than a repository's.
    def resolve(url)
      view = @github.repo_view(url, VIEW_FIELDS)
      SkillSupport::Identifiers.repository!(view.is_a?(Hash) ? view['nameWithOwner'] : nil)
    rescue SkillSupport::InvalidIdentifier => e
      raise unless e.kind == :repository_url
    end
  end
end

# frozen_string_literal: true

module Do
  # `preflight check` on the push remote: every URL it pushes to must be on
  # the issue's host and resolve, through GitHub, to this repository or a
  # fork of it the user can write to. The hosts are all checked before gh is
  # asked about any URL.
  class PushRemote
    VIEW_FIELDS = %w[nameWithOwner parent viewerPermission].freeze
    # A fork /do resumes from and pushes to is one the user controls, not
    # merely one they can read.
    WRITE_PERMISSIONS = %w[WRITE MAINTAIN ADMIN].freeze
    NOT_A_GH_URL = 'gh reads this URL as a local path, not a repository URL'

    # +stop_reason+ is nil when every URL passed. +urls+ are redacted, for
    # reporting; +checked_urls+ are the same URLs as git gave them, for git
    # to reach exactly what passed, and never reported, as a URL can carry a
    # token. +repositories+ are the nameWithOwner each URL resolved to, and
    # +forks+ those that are forks of this repository (on fork_not_writable,
    # the forks the user can't write to); +stderr+ is gh's answer for a URL
    # that didn't resolve.
    Verdict = Struct.new(:remote, :stop_reason, :urls, :checked_urls, :repositories, :forks, :stderr,
                         keyword_init: true) do
      def fork?
        !forks.to_a.empty?
      end
    end

    # What +view+ (gh repo view's nameWithOwner and parent) is to
    # +repository+, ignoring case as GitHub does: :this_repository, :fork for
    # a fork whose parent it is, or :other.
    def self.classify(view, repository)
      return :this_repository if SkillSupport::Identifiers.repository!(view['nameWithOwner']).casecmp?(repository)

      parent = view['parent']
      return :other unless parent.is_a?(Hash)

      "#{parent.dig('owner', 'login')}/#{parent['name']}".casecmp?(repository) ? :fork : :other
    end

    # +host+ is the issue's host and +repository+ this repository's
    # nameWithOwner as GitHub gives it.
    def initialize(checkout:, github:, host:, repository:)
      @checkout = checkout
      @github = github
      @host = host
      @repository = repository
    end

    # The Verdict on the remote named +remote+.
    def assess(remote)
      return verdict(remote, :remote_missing) unless @checkout.remote_names.include?(remote)

      urls = @checkout.push_urls(remote)
      return verdict(remote, :remote_missing) if urls.empty?
      return verdict(remote, :host_mismatch, urls) unless urls.all? { |url| SkillSupport::RemoteUrl.host(url) == @host }

      resolve(remote, urls)
    end

    private

    def resolve(remote, urls)
      views = urls.map do |url|
        view, stderr = view(url)
        return verdict(remote, :remote_unresolvable, urls, stderr: stderr) unless view

        view
      end
      classified(remote, urls, views)
    end

    def classified(remote, urls, views)
      kinds = views.map { |view| self.class.classify(view, @repository) }
      return verdict(remote, :push_remote_not_this_repository, urls) if kinds.include?(:other)

      writable(remote, urls, views, views.zip(kinds).filter_map { |view, kind| view if kind == :fork })
    end

    # Passes once the user can write to each of +forks+, the views of forks.
    def writable(remote, urls, views, forks)
      unwritable = forks.reject { |view| WRITE_PERMISSIONS.include?(view['viewerPermission']) }
      return verdict(remote, :fork_not_writable, urls, forks: names(unwritable)) unless unwritable.empty?

      Verdict.new(remote: remote, urls: redacted(urls), checked_urls: urls, repositories: names(views),
                  forks: names(forks))
    end

    # gh's view of +url+, or nil and why it didn't resolve.
    def view(url)
      [@github.repo_view(url, VIEW_FIELDS), nil]
    rescue SkillSupport::GhError => e
      [nil, e.stderr.scrub.strip]
    rescue SkillSupport::InvalidIdentifier => e
      raise unless e.kind == :repository_url

      [nil, NOT_A_GH_URL]
    end

    def verdict(remote, stop_reason, urls = [], stderr: nil, forks: [])
      Verdict.new(remote: remote, stop_reason: stop_reason, urls: redacted(urls), checked_urls: [], repositories: [],
                  forks: forks, stderr: stderr)
    end

    def names(views)
      views.map { |view| view['nameWithOwner'] }.uniq
    end

    def redacted(urls)
      urls.map { |url| SkillSupport::RemoteUrl.redacted(url) }
    end
  end
end

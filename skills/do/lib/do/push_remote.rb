# frozen_string_literal: true

require_relative 'remote_url'

module Do
  # Pre-flight step 2 for the push remote: every URL it pushes to must be on
  # the issue's host and resolve, through GitHub, to this repository or a
  # fork of it. The hosts are all checked before gh is asked about any URL.
  class PushRemote
    VIEW_FIELDS = %w[nameWithOwner parent].freeze
    NOT_A_GH_URL = 'gh reads this URL as a local path, not a repository URL'

    # +stop_reason+ is nil when every URL passed. +urls+ are redacted;
    # +repositories+ are the nameWithOwner each URL resolved to, and +forks+
    # those that are forks of this repository; +stderr+ is gh's answer for a
    # URL that didn't resolve.
    Verdict = Struct.new(:remote, :stop_reason, :urls, :repositories, :forks, :stderr, keyword_init: true) do
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
      return verdict(remote, :host_mismatch, urls) unless urls.all? { |url| RemoteUrl.host(url) == @host }

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

      names = views.map { |view| view['nameWithOwner'] }
      forks = names.zip(kinds).filter_map { |name, kind| name if kind == :fork }
      Verdict.new(remote: remote, urls: redacted(urls), repositories: names.uniq, forks: forks.uniq)
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

    def verdict(remote, stop_reason, urls = [], stderr: nil)
      Verdict.new(remote: remote, stop_reason: stop_reason, urls: redacted(urls), repositories: [], forks: [],
                  stderr: stderr)
    end

    def redacted(urls)
      urls.map { |url| RemoteUrl.redacted(url) }
    end
  end
end

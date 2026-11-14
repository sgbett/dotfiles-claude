# frozen_string_literal: true

require_relative 'checkout'
require_relative 'issue_reference'
require_relative 'reasons'

module Do
  # Where the issue /do was given lives, for pre-flight and record alike: its
  # host and repository, with a bare number naming an issue in the repository
  # origin resolves to. Every fact the scripts act on comes from that host,
  # so it must be one gh is logged in to, checked before any request to it.
  class IssueLocator
    ORIGIN_FIELDS = %w[nameWithOwner url].freeze
    URL_HOST = %r{\Ahttps?://(?<host>[^/]+)/}

    def initialize(runner)
      @runner = runner
      @checkout = Checkout.new(runner)
      @logged_in = {}
    end

    # Yields the issue's IssueReference::Reference, its host and repository
    # resolved, and returns what the block returns; or returns the stop or
    # ask that comes first: +argument+ isn't an issue reference, is a bare
    # number with no origin to resolve it through, or names a host gh isn't
    # logged in to.
    def locate(argument, &)
      reference = IssueReference.parse(argument)
      return Reasons.not_an_issue(:not_a_reference) unless reference
      return through_origin(reference.number, &) if reference.bare?

      on_logged_in_host(reference, &)
    end

    private

    # As gh resolves origin's URL: the repository is never parsed from the
    # URL, which can be an alias. Its host is, to check before gh is asked.
    def through_origin(number, &)
      url = @checkout.origin_url
      host = url && origin_host(url)
      return no_origin unless host
      return not_logged_in(host) unless logged_in?(host)

      origin = view(url)
      return no_origin unless origin

      on_logged_in_host(IssueReference::Reference.new(
                          host: answered_host(origin['url']), number: number,
                          repository: SkillSupport::Identifiers.repository!(origin['nameWithOwner'])
                        ), &)
    end

    def on_logged_in_host(reference)
      return not_logged_in(reference.host) unless logged_in?(reference.host)

      yield reference
    end

    def logged_in?(host)
      @logged_in.fetch(host) { @logged_in[host] = SkillSupport::Gh.new(host: host, runner: @runner).logged_in? }
    end

    # nil for a local path, and for a host alias that isn't a host name.
    def origin_host(url)
      SkillSupport::Identifiers.host!(SkillSupport::RemoteUrl.host(url))
    rescue SkillSupport::InvalidIdentifier
      nil
    end

    # nil when origin's URL is one gh would read as a local path and resolve
    # against github.com. repo_view takes its host from the URL, so the Gh's
    # own goes unused.
    def view(url)
      SkillSupport::Gh.new(host: IssueReference::DEFAULT_HOST, runner: @runner).repo_view(url, ORIGIN_FIELDS)
    rescue SkillSupport::InvalidIdentifier => e
      raise unless e.kind == :repository_url
    end

    def answered_host(url)
      match = URL_HOST.match(url.to_s)
      raise SkillSupport::UnexpectedResponse, 'gh repo view returned no repository URL' unless match

      SkillSupport::Identifiers.host!(match[:host])
    end

    def no_origin
      SkillSupport::Outcome.ask([Reasons.ask(Reasons::NO_ORIGIN)])
    end

    def not_logged_in(host)
      Reasons.stop(Reasons::HOST_NOT_LOGGED_IN, host: host)
    end
  end
end

# frozen_string_literal: true

require_relative 'checkout'
require_relative 'issue_reference'
require_relative 'reasons'

module Do
  # Where the issue /do was given lives, for both halves of pre-flight: its
  # host and repository, with a bare number naming an issue in the repository
  # origin resolves to.
  class IssueLocator
    ORIGIN_FIELDS = %w[nameWithOwner url].freeze
    URL_HOST = %r{\Ahttps?://(?<host>[^/]+)/}

    def initialize(runner)
      @runner = runner
      @checkout = Checkout.new(runner)
    end

    # Yields the issue's IssueReference::Reference, its host and repository
    # resolved, and returns what the block returns; or returns the stop or
    # ask that comes first: +argument+ isn't an issue reference, or is a bare
    # number with no origin to resolve it through.
    def locate(argument)
      reference = IssueReference.parse(argument)
      return Reasons.not_an_issue(:not_a_reference) unless reference

      reference = through_origin(reference.number) if reference.bare?
      return SkillSupport::Outcome.ask([Reasons.ask(Reasons::NO_ORIGIN)]) unless reference

      yield reference
    end

    private

    # As gh resolves origin's URL: never parsed from the URL, which can be an
    # alias.
    def through_origin(number)
      url = @checkout.origin_url
      origin = url && view(url)
      return unless origin

      IssueReference::Reference.new(host: host(origin['url']), number: number,
                                    repository: SkillSupport::Identifiers.repository!(origin['nameWithOwner']))
    end

    # nil when origin's URL is a local path, which gh would resolve against
    # github.com. repo_view takes its host from the URL, so the Gh's own goes
    # unused.
    def view(url)
      SkillSupport::Gh.new(host: IssueReference::DEFAULT_HOST, runner: @runner).repo_view(url, ORIGIN_FIELDS)
    rescue SkillSupport::InvalidIdentifier => e
      raise unless e.kind == :repository_url
    end

    def host(url)
      match = URL_HOST.match(url.to_s)
      raise SkillSupport::UnexpectedResponse, 'gh repo view returned no repository URL' unless match

      SkillSupport::Identifiers.host!(match[:host])
    end
  end
end

# frozen_string_literal: true

require_relative 'assessment'
require_relative 'checkout'
require_relative 'facts_report'
require_relative 'gate_file'
require_relative 'issue_query'
require_relative 'issue_reference'
require_relative 'reasons'
require_relative 'slug'

module Do
  # `preflight facts <issue>`, the read-only first half of /do's pre-flight:
  # gathers the issue's facts from GitHub and the checkout, and stops, asks
  # or proceeds with them.
  class Facts
    ORIGIN_FIELDS = %w[nameWithOwner url].freeze
    URL_HOST = %r{\Ahttps?://(?<host>[^/]+)/}

    # +argument+ names the issue as the user gave it. Every gh and git call
    # goes through +runner+, in the working directory.
    def initialize(argument, runner: SkillSupport::CommandRunner.new)
      @argument = argument
      @runner = runner
      @checkout = Checkout.new(runner)
    end

    def call
      reference = IssueReference.parse(@argument)
      return Reasons.not_an_issue(:not_a_reference) unless reference

      reference = through_origin(reference.number) if reference.bare?
      return SkillSupport::Outcome.ask([Reasons.ask(Reasons::NO_ORIGIN)]) unless reference

      facts(reference)
    end

    private

    # A bare number names an issue in the repository origin resolves to,
    # as gh resolves it: never parsed from the URL, which can be an alias.
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

    def facts(reference)
      query = IssueQuery.new(SkillSupport::Gh.new(host: reference.host, runner: @runner))
      result = query.fetch(reference.repository, reference.number)
      return Reasons.not_an_issue(result.kind) unless result.kind == :issue

      report(result, host: reference.host, parent_branches: parent_branches(query, result))
    end

    # The default base is the branch of a parent in this repository.
    def parent_branches(query, result)
      parent = result.parent
      return [] unless parent&.repository&.same_as?(result.repository)

      query.branch_names(result.repository.name_with_owner, parent.number)
    end

    def report(result, host:, parent_branches:)
      gate_path = GateFile.path(@checkout.common_directory, result.issue.id)
      default_branch = Slug.default_branch(result.issue.number, result.issue.title, runner: @runner)
      assessment = Assessment.new(result, GateFile.read(gate_path))
      fields = FactsReport.new(assessment, host: host, gate_path: gate_path, parent_branches: parent_branches,
                                           default_branch: default_branch).fields
      outcome(assessment, fields)
    end

    def outcome(assessment, fields)
      return Reasons.stop(assessment.stop_reason, **fields) if assessment.stop_reason

      asks = assessment.asks
      asks.empty? ? SkillSupport::Outcome.proceed(**fields) : SkillSupport::Outcome.ask(asks, **fields)
    end
  end
end

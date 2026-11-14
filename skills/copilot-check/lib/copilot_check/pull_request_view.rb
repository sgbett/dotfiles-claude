# frozen_string_literal: true

require 'json'

module CopilotCheck
  # The pull request a run is on, as `gh pr view` gives it: by its number in
  # the checkout's repository or, given none, the one gh finds for the
  # checkout's current branch, which gh looks up only in the repository it
  # resolves itself. Its URL must name the checkout's repository, so that
  # every later call targets the same one.
  class PullRequestView
    FIELDS = %w[number baseRefName isCrossRepository isDraft headRefOid url].freeze
    URL = %r{\Ahttps://(?<host>[^/]+)/(?<path>[^/]+/[^/]+)/pull/(?<number>[1-9][0-9]*)\z}

    # +base+ is the base branch's name; +head+ the head commit's oid.
    PullRequest = Struct.new(:number, :base, :draft, :cross_repository, :head, keyword_init: true) do
      # What the start file records: the pull request as it was when the run
      # began, as promote-check reads it.
      def start_state
        { 'number' => number, 'baseRefName' => base, 'isCrossRepository' => cross_repository, 'isDraft' => draft }
      end
    end

    # +repository+ is the CheckoutRepository::Repository.
    def initialize(runner, repository)
      @runner = runner
      @repository = repository
    end

    # The PullRequest numbered +number+, or the current branch's for nil.
    # Raises GhError when gh finds none, and UnexpectedResponse when what it
    # gives isn't that pull request of this repository.
    def fetch(number)
      arguments = ['pr', 'view', *([number.to_s, '-R', @repository.argument] if number), '--json', FIELDS.join(',')]
      result = @runner.run(['gh', *arguments])
      raise SkillSupport::GhError.new(arguments, result) unless result.success?

      pull_request(parse(result.stdout), number)
    end

    private

    def parse(output)
      view = JSON.parse(output)
      raise SkillSupport::UnexpectedResponse, 'gh pr view printed no pull request' unless view.is_a?(Hash)

      view
    rescue JSON::ParserError
      raise SkillSupport::UnexpectedResponse, 'gh pr view printed something other than JSON'
    end

    def pull_request(view, asked)
      number = SkillSupport::Identifiers.issue_number!(view['number'])
      unless (asked.nil? || number == asked) && this_repository?(view['url'], number)
        raise SkillSupport::UnexpectedResponse, "gh pr view gave another pull request than this repository's asked for"
      end

      PullRequest.new(number: number, base: base(view), draft: flag(view, 'isDraft'),
                      cross_repository: flag(view, 'isCrossRepository'),
                      head: SkillSupport::Identifiers.commit_sha!(view['headRefOid']))
    end

    def this_repository?(url, number)
      match = URL.match(url.to_s)
      !match.nil? && match[:host].casecmp?(@repository.host) && match[:path].casecmp?(@repository.name_with_owner) &&
        Integer(match[:number], 10) == number
    end

    def base(view)
      base = view['baseRefName']
      return base if base.is_a?(String) && !base.empty?

      raise SkillSupport::UnexpectedResponse, 'gh pr view gave no base branch'
    end

    def flag(view, name)
      return view[name] if [true, false].include?(view[name])

      raise SkillSupport::UnexpectedResponse, "gh pr view gave no #{name}"
    end
  end
end

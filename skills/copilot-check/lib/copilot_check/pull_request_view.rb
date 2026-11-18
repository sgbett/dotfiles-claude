# frozen_string_literal: true

require 'json'

module CopilotCheck
  # The pull request a run is on, as `gh pr view` gives it: by its number in
  # the checkout's repository or, given none, the one gh finds for the
  # checkout's current branch, which gh looks up only in the repository it
  # resolves itself. Its URL must name the checkout's repository, so that
  # every later call targets the same one.
  class PullRequestView
    FIELDS = %w[number baseRefName headRefName isCrossRepository headRepository headRepositoryOwner isDraft
                headRefOid state url autoMergeRequest].freeze
    URL = %r{\Ahttps://(?<host>[^/]+)/(?<path>[^/]+/[^/]+)/pull/(?<number>[1-9][0-9]*)\z}
    OPEN = 'OPEN'
    STATES = [OPEN, 'CLOSED', 'MERGED'].freeze

    # +base+ is the base branch's name and +head_branch+ the head branch's,
    # as GitHub gives them; +head_owner+ the login of the head repository's
    # owner, nil when gh gives none; +head_repository+ the head repository
    # as "owner/repo", nil when gh names no owner or no name; +head+ the head
    # commit's oid; +state+ one of STATES; +auto_merge+ whether auto-merge is
    # on.
    PullRequest = Struct.new(:number, :base, :head_branch, :draft, :cross_repository, :head_owner, :head_repository,
                             :head, :state, :auto_merge, keyword_init: true) do
      def open?
        state == OPEN
      end

      # What the start file records, as promote-check reads it (StartState):
      # the pull request of +repository+, the CheckoutRepository::Repository,
      # as it was when the run began, the top level of the +checkout+ the run
      # works in, and whether /do +chained+ the run.
      def start_state(repository, checkout:, chained:)
        { 'number' => number, 'repository' => repository.argument, 'baseRefName' => base,
          'isCrossRepository' => cross_repository, 'isDraft' => draft, 'checkout' => checkout, 'chained' => chained }
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
      verify(number, view['url'], asked)
      PullRequest.new(number: number, base: branch(view, 'baseRefName'), head_branch: branch(view, 'headRefName'),
                      draft: flag(view, 'isDraft'), cross_repository: flag(view, 'isCrossRepository'),
                      head_owner: head_owner(view), head_repository: head_repository(view),
                      head: SkillSupport::Identifiers.commit_sha!(view['headRefOid']), state: state(view),
                      auto_merge: auto_merge(view))
    end

    def verify(number, url, asked)
      return if (asked.nil? || number == asked) && this_repository?(url, number)

      raise SkillSupport::UnexpectedResponse, "gh pr view gave another pull request than this repository's asked for"
    end

    def this_repository?(url, number)
      match = URL.match(url.to_s)
      !match.nil? && match[:host].casecmp?(@repository.host) && match[:path].casecmp?(@repository.name_with_owner) &&
        Integer(match[:number], 10) == number
    end

    def branch(view, name)
      branch = view[name]
      return branch if branch.is_a?(String) && !branch.empty?

      raise SkillSupport::UnexpectedResponse, "gh pr view gave no #{name}"
    end

    # Nil rather than a failure when gh names no owner: the viewer isn't its
    # owner then, so the fork guards hold.
    def head_owner(view)
      owner = view['headRepositoryOwner']
      login = owner['login'] if owner.is_a?(Hash)
      login if login.is_a?(String) && !login.empty?
    end

    # From the owner's login and the repository's name, rather than the
    # repository's nameWithOwner, which some versions of gh leave empty. Nil
    # rather than a failure when gh leaves either out, as for a fork since
    # deleted: no remote can be it then, so setup stops.
    def head_repository(view)
      owner = head_owner(view)
      repository = view['headRepository']
      name = repository['name'] if repository.is_a?(Hash)
      SkillSupport::Identifiers.repository!("#{owner}/#{name}") if owner && name.is_a?(String) && !name.empty?
    end

    def flag(view, name)
      return view[name] if [true, false].include?(view[name])

      raise SkillSupport::UnexpectedResponse, "gh pr view gave no #{name}"
    end

    def state(view)
      return view['state'] if STATES.include?(view['state'])

      raise SkillSupport::UnexpectedResponse, 'gh pr view gave no state'
    end

    # Null from gh means auto-merge is off; the request means on.
    def auto_merge(view)
      request = view['autoMergeRequest']
      return request.is_a?(Hash) if view.key?('autoMergeRequest') && (request.nil? || request.is_a?(Hash))

      raise SkillSupport::UnexpectedResponse, 'gh pr view gave no autoMergeRequest'
    end
  end
end

# frozen_string_literal: true

require_relative 'checkout_repository'
require_relative 'pull_request_query'
require_relative 'reasons'

module CopilotCheck
  # `promote-check verify --pr N --head SHA`, once the lead has marked the
  # pull request ready: its head must still be SHA, the commit `check`
  # judged, and it must be open, out of draft and without auto-merge, all
  # from one read. A pull request that can't be read stops as a changed one
  # does, so the lead undoes the ready either way.
  class ReadyVerification
    OPEN = 'OPEN'

    # +options+ are PromoteCheckArguments' Options.
    def initialize(options, runner:)
      @options = options
      @runner = runner
    end

    def call
      pull_request = read
      fields = { pull_request: { number: @options.pr, head: pull_request.head, state: pull_request.state,
                                 is_draft: pull_request.draft, auto_merge: pull_request.auto_merge } }
      return Reasons.stop(Reasons::HEAD_CHANGED, **fields) unless pull_request.head == @options.head
      return Reasons.stop(Reasons::READY_STATE_UNEXPECTED, **fields) unless ready?(pull_request)

      SkillSupport::Outcome.proceed(**fields)
    rescue SkillSupport::Error => e
      Reasons.stop(Reasons::HEAD_UNREADABLE, pull_request: { number: @options.pr },
                                             session_only: { error: e.message })
    end

    private

    def read
      repository = CheckoutRepository.resolve(@runner)
      github = SkillSupport::Gh.new(host: repository.host, runner: @runner)
      PullRequestQuery.new(github).fetch(repository.name_with_owner, @options.pr)
    end

    def ready?(pull_request)
      pull_request.state == OPEN && pull_request.draft == false && pull_request.auto_merge == false
    end
  end
end

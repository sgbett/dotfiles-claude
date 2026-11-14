# frozen_string_literal: true

require_relative 'checkout_repository'
require_relative 'pull_request_query'
require_relative 'reasons'

module CopilotCheck
  # `promote-check verify --pr N --head SHA`, once the lead has marked the
  # pull request ready: its head must still be SHA, the commit `check`
  # judged. A head that can't be read stops as a changed one does, so the
  # lead undoes the ready either way.
  class ReadyVerification
    # +options+ are PromoteCheckArguments' Options.
    def initialize(options, runner:)
      @options = options
      @runner = runner
    end

    def call
      repository = CheckoutRepository.resolve(@runner)
      github = SkillSupport::Gh.new(host: repository.host, runner: @runner)
      head = PullRequestQuery.new(github).fetch(repository.name_with_owner, @options.pr).head
      pull_request = { number: @options.pr, head: head }
      return Reasons.stop(Reasons::HEAD_CHANGED, pull_request: pull_request) unless head == @options.head

      SkillSupport::Outcome.proceed(pull_request: pull_request)
    rescue SkillSupport::Error => e
      Reasons.stop(Reasons::HEAD_UNREADABLE, pull_request: { number: @options.pr },
                                             session_only: { error: e.message })
    end
  end
end

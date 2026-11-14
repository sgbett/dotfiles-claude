# frozen_string_literal: true

require 'json'
require_relative 'checkout_repository'
require_relative 'latest_review'
require_relative 'output_file'
require_relative 'pull_request_argument'
require_relative 'pull_request_view'
require_relative 'reasons'
require_relative 'setup_arguments'
require_relative 'stop'
require_relative 'timestamp'

module CopilotCheck
  # skills/copilot-check/bin/setup: Phase 0. Reads what the run starts from
  # before it writes anything: the pull request, asking first when it comes
  # from a fork; the rubric, .github/copilot-instructions.md as it stands on
  # the base branch, which the pull request can't change, where only a 404
  # means there is none; and the high-water mark, the submittedAt of
  # Copilot's latest review, or the epoch before its first. Then it writes
  # the start file, which promote-check reads, and the rubric file, empty
  # when there is none, never printing the rubric.
  class Setup
    RUBRIC = '.github/copilot-instructions.md'
    ACCEPT_FORK = '--accept-fork'

    def self.call(arguments, runner: SkillSupport::CommandRunner.new)
      new(SetupArguments.parse(arguments), runner: runner).call
    end

    # +options+ are SetupArguments' Options.
    def initialize(options, runner:)
      @options = options
      @runner = runner
    end

    def call
      number = PullRequestArgument.read(@options.argument_file)
      @repository = CheckoutRepository.resolve(@runner)
      @pull_request = PullRequestView.new(@runner, @repository).fetch(number)
      return fork_ask if fork_unaccepted?

      start(SkillSupport::Identifiers.branch!(@pull_request.base, runner: @runner))
    rescue Stop => e
      Reasons.stop(e.reason, **{ repository: @repository&.to_h, pull_request: number_field }.compact)
    end

    private

    def start(base)
      github = SkillSupport::Gh.new(host: @repository.host, runner: @runner)
      rubric = rubric(github, base)
      mark = LatestReview.new(github).submitted_at(@repository.name_with_owner, @pull_request.number)
      write(rubric)
      SkillSupport::Outcome.proceed(repository: @repository.to_h, pull_request: pull_request_fields(base),
                                    rubric_found: !rubric.nil?, high_water_mark: mark || Timestamp::EPOCH)
    end

    # A yes holds only while the head is the commit the user was asked about.
    def fork_unaccepted?
      @pull_request.cross_repository && @options.accept_fork != @pull_request.head
    end

    def fork_ask
      head = @pull_request.head
      SkillSupport::Outcome.ask([Reasons.ask(Reasons::FORK_PULL_REQUEST, accept_with: [ACCEPT_FORK, head])],
                                repository: @repository.to_h,
                                pull_request: { number: @pull_request.number, head: head })
    end

    def rubric(github, base)
      rubric = SkillSupport::RepositoryFiles.new(github).read(@repository.name_with_owner, RUBRIC, ref: base)
      raise SkillSupport::UnexpectedResponse, "#{RUBRIC} is a directory, not a file" if rubric.is_a?(Array)

      rubric
    end

    def write(rubric)
      OutputFile.write(@options.start_file, "#{JSON.generate(@pull_request.start_state)}\n")
      OutputFile.write(@options.rubric_file, rubric.to_s)
    end

    def pull_request_fields(base)
      { number: @pull_request.number, base: base, is_draft: @pull_request.draft,
        is_cross_repository: @pull_request.cross_repository }
    end

    def number_field
      { number: @pull_request.number } if @pull_request
    end
  end
end

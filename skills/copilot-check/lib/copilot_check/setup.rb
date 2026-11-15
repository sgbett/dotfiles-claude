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
  # before it writes anything: the pull request, which must be open, asking
  # first when it comes from a fork or when the checkout these scripts run
  # from may not hold the reviewed ones (SkillSupport::ScriptsCheckout); the
  # rubric, .github/copilot-instructions.md as it stands on the base branch,
  # which the pull request can't change, where only a 404 means there is
  # none; and the high-water mark, the submittedAt of Copilot's latest
  # review, or the epoch before its first. Then it writes the start file,
  # which promote-check reads, with whether /do chained the run, and the
  # rubric file, empty when there is none, never printing the rubric.
  class Setup
    RUBRIC = '.github/copilot-instructions.md'
    ACCEPT_FORK = '--accept-fork'
    SKILL_DIRECTORY = File.expand_path('../..', __dir__)

    # +skill_directory+ is where the running scripts live.
    def self.call(arguments, runner: SkillSupport::CommandRunner.new, skill_directory: SKILL_DIRECTORY)
      new(SetupArguments.parse(arguments), runner: runner, skill_directory: skill_directory).call
    end

    # +options+ are SetupArguments' Options.
    def initialize(options, runner:, skill_directory:)
      @options = options
      @runner = runner
      @skill_directory = skill_directory
    end

    def call
      number, @chained = PullRequestArgument.read(@options.argument_file)
      @repository = CheckoutRepository.resolve(@runner)
      @pull_request = PullRequestView.new(@runner, @repository).fetch(number)
      @pull_request.open? ? ask_or_start : not_open
    rescue Stop => e
      Reasons.stop(e.reason, **{ repository: @repository&.to_h, pull_request: number_field }.compact)
    end

    private

    # Asks before anything is written when the pull request comes from a
    # fork or the scripts may not be the reviewed ones, and starts once
    # nothing is left to ask.
    def ask_or_start
      scripts = examine_scripts
      asks = [fork_ask, scripts.ask].compact
      asks.empty? ? start(SkillSupport::Identifiers.branch!(@pull_request.base, runner: @runner)) : ask(asks, scripts)
    end

    def start(base)
      github = SkillSupport::Gh.new(host: @repository.host, runner: @runner)
      rubric = rubric(github, base)
      mark = LatestReview.new(github).submitted_at(@repository.name_with_owner, @pull_request.number)
      write(rubric)
      SkillSupport::Outcome.proceed(repository: @repository.to_h, pull_request: pull_request_fields(base),
                                    chained: @chained, rubric_found: !rubric.nil?,
                                    high_water_mark: mark || Timestamp::EPOCH)
    end

    def not_open
      Reasons.stop(Reasons::PULL_REQUEST_NOT_OPEN, repository: @repository.to_h,
                                                   pull_request: { number: @pull_request.number,
                                                                   state: @pull_request.state })
    end

    def examine_scripts
      SkillSupport::ScriptsCheckout.new(@runner, skill_directory: @skill_directory, reasons: Reasons)
                                   .examine(accepted: @options.accept_scripts)
    end

    # A yes holds only while the head is the commit the user was asked about.
    def fork_ask
      return unless @pull_request.cross_repository && @options.accept_fork != @pull_request.head

      Reasons.ask(Reasons::FORK_PULL_REQUEST, accept_with: [ACCEPT_FORK, @pull_request.head])
    end

    # The scripts' checkout and its changes are named in the session alone.
    def ask(asks, scripts)
      fields = { repository: @repository.to_h,
                 pull_request: { number: @pull_request.number, head: @pull_request.head } }
      if scripts.ask
        fields[:session_only] = { scripts_checkout: scripts.top_level, scripts_changes: scripts.changes.map(&:to_s) }
      end
      SkillSupport::Outcome.ask(asks, **fields)
    end

    def rubric(github, base)
      rubric = SkillSupport::RepositoryFiles.new(github).read(@repository.name_with_owner, RUBRIC, ref: base)
      raise SkillSupport::UnexpectedResponse, "#{RUBRIC} is a directory, not a file" if rubric.is_a?(Array)

      rubric
    end

    def write(rubric)
      state = @pull_request.start_state(@repository, chained: @chained)
      OutputFile.write(@options.start_file, "#{JSON.generate(state)}\n")
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

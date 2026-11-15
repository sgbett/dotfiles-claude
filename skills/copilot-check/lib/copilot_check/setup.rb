# frozen_string_literal: true

require 'json'
require_relative 'checkout_repository'
require_relative 'latest_review'
require_relative 'output_file'
require_relative 'pull_request_argument'
require_relative 'pull_request_checkout'
require_relative 'pull_request_view'
require_relative 'reasons'
require_relative 'setup_arguments'
require_relative 'stop'
require_relative 'timestamp'
require_relative 'viewer'

module CopilotCheck
  # skills/copilot-check/bin/setup: Phase 0. Reads what the run starts from
  # before it writes anything: the pull request, which must be open; the
  # checkout with its branch checked out, which the run works in, stopping
  # when it can't (PullRequestCheckout); then, asking first when the pull
  # request comes from a fork someone else owns (Viewer) or when the
  # checkout these scripts run from may not hold the reviewed ones
  # (SkillSupport::ScriptsCheckout), what stands on the base branch, which
  # the pull request can't change: the rubric,
  # .github/copilot-instructions.md, where only a 404 means there is none,
  # and the repository's security focus (SkillSupport::SecurityFocus), which
  # the security gate reviews Copilot's fixes against; and the high-water
  # mark, the submittedAt of Copilot's latest review, or the epoch before its
  # first. Then it writes the start file, which promote-check
  # reads, with the checkout and whether /do chained the run, and the rubric
  # and focus files, each empty when there is none, never printing either.
  # A checkout's path is machine-local, so only session_only names it.
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

    # Stops on a checkout the run can't work in, then asks before anything
    # is written when the pull request comes from a fork someone else owns
    # or the scripts may not be the reviewed ones, and starts once nothing
    # is left to ask.
    def ask_or_start
      scripts = examine_scripts
      @checkout = assess_checkout(scripts.top_level)
      return checkout_stop if @checkout.stop_reason

      asks = [fork_ask, scripts.ask].compact
      asks.empty? ? start(SkillSupport::Identifiers.branch!(@pull_request.base, runner: @runner)) : ask(asks, scripts)
    end

    def start(base)
      rubric = rubric(github, base)
      focus = SkillSupport::SecurityFocus.new(SkillSupport::RepositoryFiles.new(github))
                                         .read(@repository.name_with_owner, base)
      mark = LatestReview.new(github).submitted_at(@repository.name_with_owner, @pull_request.number)
      write(rubric, focus)
      started(base, rubric, focus, mark)
    end

    # +focus+ is the SkillSupport::SecurityFocus::Result, whose text only
    # the focus file holds.
    def started(base, rubric, focus, mark)
      SkillSupport::Outcome.proceed(repository: @repository.to_h, pull_request: pull_request_fields(base),
                                    push_remote: @checkout.push_remote, chained: @chained,
                                    rubric_found: !rubric.nil?,
                                    security_focus: { found: focus.found?, sources: focus.sources },
                                    high_water_mark: mark || Timestamp::EPOCH,
                                    session_only: { checkout: @checkout.top_level })
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

    # +scripts_top_level+ is the top level of the checkout the scripts run
    # from, if any.
    def assess_checkout(scripts_top_level)
      branch = SkillSupport::Identifiers.branch!(@pull_request.head_branch, runner: @runner)
      PullRequestCheckout.new(@runner, scripts_top_level: scripts_top_level).assess(branch, @pull_request.head)
    end

    def checkout_stop
      pull_request = { number: @pull_request.number, head_branch: @pull_request.head_branch, head: @pull_request.head }
      session_only = { checkout: @checkout.top_level } if @checkout.top_level
      Reasons.stop(@checkout.stop_reason, **{ repository: @repository.to_h, pull_request: pull_request,
                                              local_head: @checkout.head, session_only: session_only }.compact)
    end

    # A yes holds only while the head is the commit the user was asked about.
    # A fork the viewer owns isn't asked about: only they, and whoever they
    # let, can push to it, and the checkout, found at the pull request's
    # head, ties the head to theirs.
    def fork_ask
      return unless @pull_request.cross_repository && @options.accept_fork != @pull_request.head
      return if Viewer.new(github).owns_head?(@pull_request)

      Reasons.ask(Reasons::FORK_PULL_REQUEST, accept_with: [ACCEPT_FORK, @pull_request.head])
    end

    def github
      @github ||= SkillSupport::Gh.new(host: @repository.host, runner: @runner)
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

    def write(rubric, focus)
      state = @pull_request.start_state(@repository, checkout: @checkout.top_level, chained: @chained)
      OutputFile.write(@options.start_file, "#{JSON.generate(state)}\n")
      OutputFile.write(@options.rubric_file, rubric.to_s)
      OutputFile.write(@options.focus_file, focus.text)
    end

    def pull_request_fields(base)
      { number: @pull_request.number, base: base, head_branch: @pull_request.head_branch,
        is_draft: @pull_request.draft, is_cross_repository: @pull_request.cross_repository }
    end

    def number_field
      { number: @pull_request.number } if @pull_request
    end
  end
end

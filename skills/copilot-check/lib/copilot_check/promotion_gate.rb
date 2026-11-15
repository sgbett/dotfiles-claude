# frozen_string_literal: true

require_relative 'body_files'
require_relative 'changed_files'
require_relative 'checkout_repository'
require_relative 'checks'
require_relative 'documented_failures'
require_relative 'gate_report'
require_relative 'promotion_rules'
require_relative 'pull_request_query'
require_relative 'reasons'
require_relative 'start_state'
require_relative 'threads'
require_relative 'verdict'

module CopilotCheck
  # `promote-check check --pr N --rules-file PATH --start-file PATH
  # --outcome OUTCOME [--reviews-without-findings IDS --bodies-dir PATH]`:
  # reads every fact Phase 6's conditions rest on, fresh from GitHub and the
  # checkout the start file records, and gives the Verdict. A HOLD is no
  # stop, as the lead goes on to report it; this stops only where the thread
  # fetch does.
  class PromotionGate
    UNKNOWN = 'UNKNOWN'

    # +options+ are PromoteCheckArguments' Options.
    def initialize(options, runner:)
      @options = options
      @runner = runner
    end

    # The files the lead wrote are read before anything is asked of GitHub;
    # the start file's repository is checked once the checkout's is known.
    def call
      rules = PromotionRules.read(@options.rules_file)
      start = StartState.read(@options.start_file, @options.pr)
      @repository = CheckoutRepository.resolve(@runner)
      start.check_repository!(@repository)
      @github = SkillSupport::Gh.new(host: @repository.host, runner: @runner)
      report(Verdict.new(facts(rules, start)))
    rescue Stop => e
      Reasons.stop(e.reason, repository: GateReport.repository_fields(@repository),
                             pull_request: { number: @options.pr })
    end

    private

    def report(verdict)
      SkillSupport::Outcome.proceed(**GateReport.new(repository: @repository, number: @options.pr,
                                                     verdict: verdict).fields)
    end

    # +start+ is the StartState.
    def facts(rules, start)
      pull_request = PullRequestQuery.new(@github).fetch(name, @options.pr)
      Verdict::Facts.new(rules: rules, started_as_draft: start.draft?, chained: start.chained?,
                         outcome: @options.outcome, pull_request: pull_request,
                         reviews_without_findings: @options.reviews_without_findings,
                         **fetched(rules, pull_request, start.checkout))
    end

    # Read in this order, Phase 6's, so that mergeable, re-read only after
    # the checks, has had longest to settle from UNKNOWN.
    def fetched(rules, pull_request, checkout)
      threads = Threads.new(@github).fetch(name, @options.pr)
      { threads: threads, reviews_read: reviews_read(threads), local_head: local_head(checkout),
        files: ChangedFiles.new(@github).list(name, @options.pr, changed_files: pull_request.changed_files),
        checks: checks(rules), mergeable: mergeable(pull_request) }
    end

    # The to-do reviews given as free of findings whose body file the run
    # read is still their body.
    def reviews_read(threads)
      given = threads.todo_reviews.select { |review| @options.reviews_without_findings.include?(review.review_id) }
      BodyFiles.current_reviews(@options.bodies_dir, given)
    end

    def checks(rules)
      Checks.new(@github, DocumentedFailures.new(@github, name, rules.expected_failures)).list(name, @options.pr)
    end

    def mergeable(pull_request)
      return pull_request.mergeable unless pull_request.mergeable == UNKNOWN

      PullRequestQuery.new(@github).fetch(name, @options.pr).mergeable
    end

    # The commit checked out in +checkout+, from which the run pushed.
    def local_head(checkout)
      head = SkillSupport::Git.new(@runner).output('-C', checkout, 'rev-parse', '--verify', 'HEAD').chomp
      SkillSupport::Identifiers.commit_sha!(head)
    end

    def name
      @repository.name_with_owner
    end
  end
end

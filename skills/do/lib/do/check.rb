# frozen_string_literal: true

require_relative 'branch_assessment'
require_relative 'branch_facts'
require_relative 'branch_pull_requests'
require_relative 'check_arguments'
require_relative 'check_query'
require_relative 'check_report'
require_relative 'checkout'
require_relative 'issue_locator'
require_relative 'push_remote'
require_relative 'reasons'
require_relative 'records'
require_relative 'scripts_checkout'
require_relative 'security_focus'
require_relative 'trust'

module Do
  # `preflight check <issue> --push-remote R --pr-target owner/repo --base B
  # --branch NAME [--accept-local-branch SHA] [--accept-scripts DIGEST]`,
  # the second half of /do's pre-flight: checks the conventions the lead
  # resolved against GitHub and the checkout, one step at a time, and stops
  # at the first that fails. The remotes come first, so no branch of a
  # checkout of some other repository is ever looked at.
  class Check
    # +arguments+ follow `check`. Every gh and git call goes through
    # +runner+; +skill_directory+ is where the running scripts live.
    def initialize(arguments, runner: SkillSupport::CommandRunner.new,
                   skill_directory: ScriptsCheckout::SKILL_DIRECTORY)
      @arguments = arguments
      @runner = runner
      @skill_directory = skill_directory
      @checkout = Checkout.new(runner)
    end

    def call
      @options = CheckArguments.parse(@arguments, runner: @runner)
      IssueLocator.new(@runner).locate(@options.reference) { |reference| check(reference) }
    end

    private

    # Each step returns the stop that ends the run, or nil to go on.
    def check(reference)
      @host = reference.host
      @github = SkillSupport::Gh.new(host: @host, runner: @runner)
      @query = CheckQuery.new(@github)
      issue_stop(reference) || conventions_stop || finish
    end

    def conventions_stop
      pr_target_stop || branch_name_stop || push_remote_stop || base_stop || branch_stop || pull_request_stop
    end

    # This repository by the name GitHub gives it now, so that a renamed
    # one still matches the remotes.
    def issue_stop(reference)
      @issue = @query.issue(reference.repository, reference.number)
      @report = CheckReport.new(@options, repository: @issue.repository, host: @host)
      Reasons.not_an_issue(@issue.kind) unless @issue.kind == :issue
    end

    def pr_target_stop
      stop(Reasons::PR_TARGET_NOT_THIS_REPOSITORY) unless @options.pr_target.casecmp?(@issue.repository)
    end

    # Ignoring case, as a checkout on a case-insensitive file system holds
    # Master and master as one branch.
    def branch_name_stop
      reserved = [@options.base, @issue.default_branch].compact
      stop(Reasons::BRANCH_IS_BASE_OR_DEFAULT) if reserved.any? { |name| name.casecmp?(@options.branch) }
    end

    def push_remote_stop
      @remote = PushRemote.new(checkout: @checkout, github: @github, host: @host, repository: @issue.repository)
                          .assess(@options.push_remote)
      @report.remote = @remote
      stop(@remote.stop_reason) if @remote.stop_reason
    end

    # Never creates or pushes a base: one that's missing stops the run.
    def base_stop
      @base_commit = @query.base_commit(@issue.repository, @options.base)
      stop(Reasons::BASE_MISSING) unless @base_commit
    end

    def branch_stop
      facts = BranchFacts.new(@runner, remote: @options.push_remote, urls: @remote.checked_urls)
                         .collect(@options.branch)
      @branch = BranchAssessment.new(facts, branch: @options.branch, remote: @options.push_remote,
                                            accepted_tip: @options.accept_local_branch)
      @report.branch = @branch
      stop(@branch.stop_reason) if @branch.stop_reason
    end

    def pull_request_stop
      pull_requests = BranchPullRequests.new(@query.pull_requests(@issue.repository, @options.branch),
                                             push_repositories: @remote.repositories, trust: trust)
      @report.pull_requests = pull_requests
      stop(Reasons::UNTRUSTED_PULL_REQUEST) if pull_requests.untrusted?
    end

    def finish
      asks = [@branch.ask, examine_scripts.ask].compact
      read_security_focus
      @report.changes = @checkout.changes
      fields = @report.fields
      asks.empty? ? SkillSupport::Outcome.proceed(**fields) : SkillSupport::Outcome.ask(asks, **fields)
    end

    def examine_scripts
      @report.scripts = ScriptsCheckout.new(@runner, skill_directory: @skill_directory)
                                       .examine(work_tree: @checkout.top_level, accepted: @options.accept_scripts)
    end

    # At the base branch's commit, so every file comes from one snapshot.
    def read_security_focus
      @report.focus = SecurityFocus.new(SkillSupport::RepositoryFiles.new(@github))
                                   .read(@issue.repository, @base_commit)
    end

    # Pull requests into this repository were written in it.
    def trust
      Trust.new(viewer: @issue.viewer, home: Repository.new(name_with_owner: @issue.repository,
                                                            owner: @issue.repository.split('/').first))
    end

    def stop(reason)
      Reasons.stop(reason, **@report.fields)
    end
  end
end

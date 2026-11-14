# frozen_string_literal: true

require_relative 'reference_files'

module Do
  # The fields of `preflight check` output, in the order the lead reads
  # them: whatever the run had established when it stopped, asked or went
  # on. GitHub text sits only under "github_text"; push URLs, fork names,
  # paths, commit subjects and gh's stderr only under "session_only".
  class CheckReport
    THIS_REPOSITORY = 'this repository'
    A_FORK = 'a fork of this repository'
    NO_FOCUS = 'none'
    RESUME_POINTS = {
      new: 'none: the branch is new',
      resume_local: 'the local branch',
      resume_push_remote: "the push remote's copy",
      local_branch_unpushed: 'the local branch, once the user accepts its commits the push remote lacks',
      checked_out_pr: 'none: the local branch is a checked-out pull request, and the push remote has no copy',
      remote_tips_differ: "none: the push remote's URLs hold different copies"
    }.freeze
    ACCEPTED = 'the local branch, which the user accepted with commits the push remote lacks'
    FRESH_WORKTREE = "the push remote's copy, in a fresh worktree beside the local branch, a checked-out pull request"

    # Each is set once its step has run: the PushRemote::Verdict, the
    # BranchAssessment, the BranchPullRequests, the ScriptsCheckout's
    # Inspection, the SkillSupport::SecurityFocus::Result and the working
    # tree's Porcelain entries.
    attr_writer :remote, :branch, :pull_requests, :scripts, :focus, :changes

    # +options+ are CheckArguments' Options; +repository+ this repository's
    # nameWithOwner as GitHub gives it; +host+ the issue's host.
    def initialize(options, repository:, host:)
      @options = options
      @repository = repository
      @host = host
    end

    def fields
      { summary: summary, repository: { name_with_owner: @repository, host: @host },
        push_remote: @options.push_remote, push_remote_is_fork: (@remote.fork? if remote_passed?),
        pr_target: @options.pr_target, base: @options.base, branch: branch,
        scripts_in_work_tree: @scripts&.in_work_tree, security_focus: security_focus,
        working_tree_clean: @changes&.empty?, read: read, session_only: session_only }.compact
    end

    private

    def remote_passed?
      !@remote.nil? && @remote.stop_reason.nil?
    end

    def summary
      { push_remote: (push_remote_summary if remote_passed?), pr_target: @options.pr_target, base: @options.base,
        branch: @options.branch, resume_point: (resume_point if @branch),
        security_focus: (focus_summary if @focus) }.compact
    end

    def push_remote_summary
      "#{@options.push_remote}, #{@remote.fork? ? A_FORK : THIS_REPOSITORY}"
    end

    def focus_summary
      @focus.found? ? @focus.sources.join(', ') : NO_FOCUS
    end

    def resume_point
      return ACCEPTED if @branch.accepted?
      return FRESH_WORKTREE if @branch.fresh_worktree?

      RESUME_POINTS.fetch(@branch.state)
    end

    # remote_tip is the commit a resume from the push remote checks out;
    # remote_tips, given only when they differ, are each push URL's.
    def branch
      return unless @branch

      facts = @branch.facts
      { name: @options.branch, state: @branch.state, local_tip: facts.local_tip, remote_tip: facts.remote_tip,
        remote_tips: (facts.remote_tips if facts.remote_tips_differ?), accepted: @branch.accepted?,
        fresh_worktree: @branch.fresh_worktree?, pull_requests: @pull_requests&.to_a }.compact
    end

    def security_focus
      return unless @focus

      { found: @focus.found?, sources: @focus.sources, github_text: { text: @focus.text } }
    end

    def read
      return unless remote_passed? && @branch

      ReferenceFiles.applicable(resuming: @branch.resuming?, other_repositories: @remote.fork?, open_gate: false)
    end

    def session_only
      remote_details.merge(branch_details, checkout_details).compact
    end

    # The forks are those the remote passed with, or on fork_not_writable
    # those the user can't write to.
    def remote_details
      return {} unless @remote

      { push_urls: @remote.urls, push_remote_forks: (@remote.forks if remote_passed? || @remote.fork?),
        stderr: @remote.stderr }
    end

    # Commit subjects can carry issue text.
    def branch_details
      facts = @branch&.facts
      return {} unless facts&.lacking

      { local_branch_commits: facts.lacking, local_branch_commits_truncated: facts.more_lacking,
        local_branch_commits_approximate: facts.lacking_approximate }
    end

    def checkout_details
      { changed_paths: @changes&.map(&:to_s), scripts_checkout: @scripts&.top_level,
        scripts_changes: @scripts&.changes&.map(&:to_s) }
    end
  end
end

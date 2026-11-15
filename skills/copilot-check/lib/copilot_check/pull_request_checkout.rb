# frozen_string_literal: true

require_relative 'branch_upstream'
require_relative 'reasons'
require_relative 'worktrees'

module CopilotCheck
  # The checkout a run works in: the worktree of the working directory's
  # repository that has the pull request's branch checked out, found
  # through Worktrees so that /do's worktree counts. Claude Code resets the
  # shell's working directory to the session's after each command, so a run
  # chained from /do's worktree can't cd there, and a run from another
  # branch would commit and push there. The run stops unless the checkout
  # isn't the one its scripts run from, whose scripts its fixes would
  # change, its branch's upstream is the pull request's branch on a remote,
  # where the run pushes, and its HEAD is the pull request's head, the code
  # Copilot reviews.
  class PullRequestCheckout
    # branch.<name>.remote "." tracks a branch of this same repository.
    THIS_REPOSITORY = '.'

    # +top_level+ is the checkout's top level, symlinks resolved, and +head+
    # its HEAD's commit, both nil when no checkout has the branch;
    # +push_remote+ the remote its upstream is on, nil unless that upstream
    # is the pull request's branch; +stop_reason+ nil when the run can work
    # there.
    Assessment = Struct.new(:top_level, :head, :push_remote, :stop_reason, keyword_init: true)

    # +scripts_top_level+ is the top level of the checkout the scripts run
    # from, nil when they run from none (SkillSupport::ScriptsCheckout).
    def initialize(runner, scripts_top_level:)
      @runner = runner
      @scripts_top_level = scripts_top_level
    end

    # The Assessment for the pull request whose branch is +branch+, a name
    # Identifiers.branch! took, and whose head commit is +head+.
    def assess(branch, head)
      worktree = Worktrees.new(@runner).checked_out(branch)
      return Assessment.new(stop_reason: Reasons::NO_PULL_REQUEST_CHECKOUT) unless worktree

      top_level = top_level(worktree.path)
      local_head = SkillSupport::Identifiers.commit_sha!(worktree.head)
      remote = push_remote(top_level, branch) unless top_level == @scripts_top_level
      Assessment.new(top_level: top_level, head: local_head, push_remote: remote,
                     stop_reason: stop_reason(top_level, remote, local_head == head))
    end

    private

    # In the order the user puts each right: which checkout, then where it
    # pushes, then what it holds, as pushing or pulling needs the upstream.
    def stop_reason(top_level, remote, at_head)
      return Reasons::CHECKOUT_RUNS_SCRIPTS if top_level == @scripts_top_level
      return Reasons::NO_UPSTREAM unless remote

      Reasons::CHECKOUT_NOT_AT_HEAD unless at_head
    end

    # The remote, when the branch's upstream is the pull request's branch
    # on one. Raises InvalidIdentifier for a remote whose name isn't safe on
    # the lead's command lines, where it goes.
    def push_remote(top_level, branch)
      remote, ref = BranchUpstream.new(@runner).read(top_level, branch)
      return unless ref == "refs/heads/#{branch}" && remote != THIS_REPOSITORY

      SkillSupport::Identifiers.remote!(remote)
    end

    # git lists a worktree whose directory is gone until it is pruned.
    def top_level(path)
      File.realpath(path)
    rescue SystemCallError => e
      raise SkillSupport::Error, "the worktree with the pull request's branch checked out can't be read " \
                                 "(#{e.message}); git worktree prune forgets one whose directory is gone"
    end
  end
end

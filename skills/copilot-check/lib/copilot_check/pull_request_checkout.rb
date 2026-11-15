# frozen_string_literal: true

require_relative 'branch_upstream'
require_relative 'push_remote'
require_relative 'reasons'
require_relative 'worktree_identity'
require_relative 'worktrees'

module CopilotCheck
  # The checkout a run works in: the worktree of the working directory's
  # repository that has the pull request's branch checked out, found
  # through Worktrees so that /do's worktree counts. Claude Code resets the
  # shell's working directory to the session's after each command, so a run
  # chained from /do's worktree can't cd there, and a run from another
  # branch would commit and push there. The run stops unless the checkout's
  # path can go on the lead's command lines, the directory at its listed
  # path is that checkout still (WorktreeIdentity), it isn't the one the
  # scripts run from, whose scripts its fixes would change, its branch's
  # upstream is the pull request's branch on a remote that pushes to the
  # head repository alone (PushRemote), where the run pushes, and its HEAD
  # is the pull request's head, the code Copilot reviews.
  class PullRequestCheckout
    # branch.<name>.remote "." tracks a branch of this same repository.
    THIS_REPOSITORY = '.'
    # The lead single-quotes the checkout's path on its command lines, as
    # git -C '{checkout}' and cd '{checkout}' &&, where a quote in it ends
    # the quoting and a control character can break the line or hide what
    # follows. Every other value there is validated already.
    UNSAFE_PATH = /['[:cntrl:]]/

    # +top_level+ is the checkout's top level, symlinks resolved, and +head+
    # its HEAD's commit, both nil when no checkout has the branch;
    # +push_remote+ the remote its upstream is on, nil unless that upstream
    # is the pull request's branch on a remote that pushes to the head
    # repository alone; +stop_reason+ nil when the run can work there.
    Assessment = Struct.new(:top_level, :head, :push_remote, :stop_reason, keyword_init: true)

    # +github+ is the SkillSupport::Gh for the repository's host, and
    # +scripts_top_level+ the top level of the checkout the scripts run
    # from, nil when they run from none (SkillSupport::ScriptsCheckout).
    def initialize(runner, github:, scripts_top_level:)
      @runner = runner
      @github = github
      @scripts_top_level = scripts_top_level
    end

    # The Assessment for the pull request whose branch is +branch+, a name
    # Identifiers.branch! took, whose head commit is +head+, and whose head
    # repository is +head_repository+ ("owner/repo"), nil when GitHub names
    # none. Stops, in the order the user puts each right: which checkout,
    # then where it pushes, then what it holds, as pushing or pulling needs
    # the upstream.
    def assess(branch, head, head_repository)
      worktree = Worktrees.new(@runner).checked_out(branch)
      return Assessment.new(stop_reason: Reasons::NO_PULL_REQUEST_CHECKOUT) unless worktree

      top_level = top_level(worktree.path)
      local_head = SkillSupport::Identifiers.commit_sha!(worktree.head)
      stop_reason = checkout_stop_reason(top_level, branch, local_head)
      remote, stop_reason = push_remote(top_level, branch, head_repository) unless stop_reason
      Assessment.new(top_level: top_level, head: local_head, push_remote: remote,
                     stop_reason: stop_reason || (Reasons::CHECKOUT_NOT_AT_HEAD unless local_head == head))
    end

    private

    # +local_head+ is the commit git listed the checkout's HEAD at.
    def checkout_stop_reason(top_level, branch, local_head)
      return Reasons::CHECKOUT_PATH_UNSAFE if UNSAFE_PATH.match?(top_level)
      return Reasons::CHECKOUT_MISMATCH unless WorktreeIdentity.new(@runner).confirmed?(top_level, branch, local_head)

      Reasons::CHECKOUT_RUNS_SCRIPTS if top_level == @scripts_top_level
    end

    # [the remote, nil] when the branch's upstream is the pull request's
    # branch on a remote that pushes to the head repository alone, else
    # [nil, why not].
    def push_remote(top_level, branch, head_repository)
      remote = upstream_remote(top_level, branch)
      return [nil, Reasons::NO_UPSTREAM] unless remote
      return [nil, Reasons::PUSH_REMOTE_NOT_HEAD_REPOSITORY] unless pushes_to_head?(top_level, remote, head_repository)

      [remote, nil]
    end

    # The remote, when the branch's upstream is the pull request's branch
    # on one. Raises InvalidIdentifier for a remote whose name isn't safe on
    # the lead's command lines, where it goes.
    def upstream_remote(top_level, branch)
      remote, ref = BranchUpstream.new(@runner).read(top_level, branch)
      return unless ref == "refs/heads/#{branch}" && remote != THIS_REPOSITORY

      SkillSupport::Identifiers.remote!(remote)
    end

    # No remote can push to a head repository GitHub doesn't name.
    def pushes_to_head?(top_level, remote, head_repository)
      !head_repository.nil? && PushRemote.new(@runner, @github).pushes_only_to?(top_level, remote, head_repository)
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

# frozen_string_literal: true

require_relative 'reasons'

module Do
  # `preflight check`'s judgement of the branch the conventions name, made
  # from its BranchFacts alone. Resume on it only if it is on the push remote,
  # or is local, tracks the same-named branch there and isn't ahead of it. A
  # local branch whose remote or pushRemote is a URL or another remote, or
  # whose merge ref is refs/pull/..., is a checked-out pull request, never
  # resumed on: the run resumes from the push remote's copy instead, in a
  # fresh worktree, or stops when there is none. Any other local branch
  # needs the user's yes, given for the tip they saw. Push URLs that differ
  # on the branch leave no copy to resume from.
  class BranchAssessment
    ACCEPT_FLAG = '--accept-local-branch'
    PULL_REFS = 'refs/pull/'
    # branch.<name>.remote "." tracks a branch of this same repository, which
    # `gh pr checkout` never sets up.
    THIS_REPOSITORY = '.'
    RESUMING = %i[resume_local resume_push_remote local_branch_unpushed].freeze
    STOPS = { checked_out_pr: Reasons::CHECKED_OUT_PR, remote_tips_differ: Reasons::REMOTE_TIPS_DIFFER }.freeze

    # :new, :resume_local, :resume_push_remote, :local_branch_unpushed, or
    # one of STOPS' keys.
    attr_reader :state, :facts

    # +remote+ is the push remote's name; +accepted_tip+ the tip a yes to
    # local_branch_unpushed was given for, if any.
    def initialize(facts, branch:, remote:, accepted_tip: nil)
      @facts = facts
      @branch = branch
      @remote = remote
      @accepted_tip = accepted_tip
      @accepted = false
      @fresh_worktree = false
      @state = decide
    end

    # Whether the user's yes is what lets the run resume on the local branch.
    def accepted?
      @accepted
    end

    # Whether the run resumes from the push remote's copy beside a local
    # branch of the same name, a checked-out pull request it leaves alone.
    def fresh_worktree?
      @fresh_worktree
    end

    # Whether the run picks up work already on the branch, or would on a yes.
    def resuming?
      RESUMING.include?(state)
    end

    # The reason the run stops on the branch, or nil.
    def stop_reason
      STOPS[state]
    end

    # The ask entry for local_branch_unpushed, or nil.
    def ask
      return unless state == :local_branch_unpushed

      Reasons.ask(Reasons::LOCAL_BRANCH_UNPUSHED, accept_with: [ACCEPT_FLAG, facts.local_tip])
    end

    private

    def decide
      return :remote_tips_differ if facts.remote_tips_differ?
      return facts.remote_tip ? :resume_push_remote : :new unless facts.local_tip

      with_local_branch
    end

    def with_local_branch
      return beside_checked_out_pull_request if checked_out_pull_request?
      return :resume_local if tracks_push_remote_copy? && !ahead?
      return accept if facts.local_tip == @accepted_tip

      :local_branch_unpushed
    end

    def beside_checked_out_pull_request
      return :checked_out_pr unless facts.remote_tip

      @fresh_worktree = true
      :resume_push_remote
    end

    def checked_out_pull_request?
      [facts.tracking_remote, facts.push_remote].compact.any? { |value| ![@remote, THIS_REPOSITORY].include?(value) } ||
        facts.merge.to_s.start_with?(PULL_REFS)
    end

    def tracks_push_remote_copy?
      !facts.remote_tip.nil? && facts.tracking_remote == @remote && facts.merge == "refs/heads/#{@branch}"
    end

    # Unknown counts as ahead.
    def ahead?
      facts.lacking.nil? || !facts.lacking.empty?
    end

    def accept
      @accepted = true
      :resume_local
    end
  end
end

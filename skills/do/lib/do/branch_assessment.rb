# frozen_string_literal: true

require_relative 'reasons'

module Do
  # Pre-flight step 2's judgement of the branch the conventions name, made
  # from its BranchFacts alone. Resume on it only if it is on the push remote,
  # or is local, tracks the same-named branch there and isn't ahead of it. A
  # local branch whose remote or pushRemote is a URL or another remote, or
  # whose merge ref is refs/pull/..., is a checked-out pull request, never
  # resumed on. Any other local branch needs the user's yes, given for the
  # tip they saw.
  class BranchAssessment
    ACCEPT_FLAG = '--accept-local-branch'
    PULL_REFS = 'refs/pull/'
    # branch.<name>.remote "." tracks a branch of this same repository, which
    # `gh pr checkout` never sets up.
    THIS_REPOSITORY = '.'
    RESUMING = %i[resume_local resume_push_remote local_branch_unpushed].freeze

    # :new, :resume_local, :resume_push_remote, :checked_out_pr or
    # :local_branch_unpushed.
    attr_reader :state, :facts

    # +remote+ is the push remote's name; +accepted_tip+ the tip a yes to
    # local_branch_unpushed was given for, if any.
    def initialize(facts, branch:, remote:, accepted_tip: nil)
      @facts = facts
      @branch = branch
      @remote = remote
      @accepted_tip = accepted_tip
      @accepted = false
      @state = decide
    end

    # Whether the user's yes is what lets the run resume on the local branch.
    def accepted?
      @accepted
    end

    # A checked-out pull request's branch can still be resumed from the push
    # remote's copy, in a fresh worktree.
    def resume_from_push_remote?
      state == :checked_out_pr && !facts.remote_tip.nil?
    end

    # Whether the run picks up work already on the branch, or would on a yes.
    def resuming?
      RESUMING.include?(state)
    end

    # The ask entry for local_branch_unpushed, or nil.
    def ask
      return unless state == :local_branch_unpushed

      Reasons.ask(Reasons::LOCAL_BRANCH_UNPUSHED, accept_with: [ACCEPT_FLAG, facts.local_tip])
    end

    private

    def decide
      return facts.remote_tip ? :resume_push_remote : :new unless facts.local_tip
      return :checked_out_pr if checked_out_pull_request?
      return :resume_local if tracks_push_remote_copy? && !ahead?
      return accept if facts.local_tip == @accepted_tip

      :local_branch_unpushed
    end

    def checked_out_pull_request?
      [facts.tracking_remote, facts.push_remote].compact.any? { |value| ![@remote, THIS_REPOSITORY].include?(value) } ||
        facts.merge.to_s.start_with?(PULL_REFS)
    end

    def tracks_push_remote_copy?
      !facts.remote_tip.nil? && facts.tracking_remote == @remote && facts.merge == "refs/heads/#{@branch}"
    end

    # Unknown, when the remote's tip couldn't be fetched, counts as ahead.
    def ahead?
      facts.lacking.nil? || !facts.lacking.empty?
    end

    def accept
      @accepted = true
      :resume_local
    end
  end
end

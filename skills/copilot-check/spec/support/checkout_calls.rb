# frozen_string_literal: true

module CopilotCheck
  module Testing
    # setup's look for the checkout with #18's branch checked out
    # (PullRequestCheckout), as a unit spec's fake runner answers it.
    # ScriptCalls includes it.
    module CheckoutCalls
      # #18's head branch, as recorded.
      HEAD_BRANCH = 'feat/17-do-qa-records-the-work-as'
      WORKTREE_LIST = %w[git worktree list --porcelain -z].freeze
      UPSTREAM_FORMAT = '--format=%(upstream:remotename)%00%(upstream:remoteref)'
      # How for-each-ref gives an upstream on origin's copy of #18's branch.
      ORIGIN_UPSTREAM = "origin\0refs/heads/#{HEAD_BRANCH}\n".freeze
      # Where origin pushes: this repository, through the URL its push URL
      # fixture was recorded with.
      ORIGIN_URL = 'https://github.com/sgbett/dotfiles-claude.git'

      # The checkout a unit spec's setup finds #18's branch in: the
      # sandbox's working directory, as one that exists to resolve.
      def pull_request_checkout
        sandbox.work_directory
      end

      # What `git worktree list --porcelain -z` prints for +worktrees+, each
      # its path:, head: and branch:, nil for a detached HEAD; an empty line
      # ends each.
      def worktree_list(*worktrees)
        worktrees.map do |worktree|
          branch = worktree[:branch] ? "branch refs/heads/#{worktree[:branch]}" : 'detached'
          ["worktree #{worktree[:path]}", "HEAD #{worktree[:head]}", branch, ''].map { |line| "#{line}\0" }.join
        end.join
      end

      # setup's look for the checkout with #18's branch checked out: the
      # branch's check, then the worktrees git lists, by default the one
      # +checkout+ with that branch at #18's head, then, unless nil, the
      # +upstream+ its branch tracks, as for-each-ref prints it, and then,
      # unless nil, where origin pushes (expect_push_url_step).
      def expect_checkout_step(checkout: pull_request_checkout, upstream: ORIGIN_UPSTREAM, pushes_to: GateCalls::HERE,
                               worktrees: [{ path: checkout, head: GateCalls::HEAD, branch: HEAD_BRANCH }])
        fake_runner.expect_call(['git', 'check-ref-format', '--branch', HEAD_BRANCH], stdout: "#{HEAD_BRANCH}\n")
        fake_runner.expect_call(WORKTREE_LIST, stdout: worktree_list(*worktrees))
        return unless upstream

        fake_runner.expect_call(['git', '-C', checkout, 'for-each-ref', UPSTREAM_FORMAT, "refs/heads/#{HEAD_BRANCH}"],
                                stdout: upstream)
        expect_push_url_step(checkout, pushes_to) if pushes_to
      end

      # The read of origin's push URL in +checkout+, and gh resolving it to
      # +repository+: this one as recorded, any other synthesised.
      def expect_push_url_step(checkout, repository)
        fake_runner.expect_call(['git', '-C', checkout, 'remote', 'get-url', '--push', '--all', 'origin'],
                                stdout: "#{ORIGIN_URL}\n")
        view = if repository == GateCalls::HERE
                 fixture('repo-view/push-url.json')
               else
                 JSON.generate('nameWithOwner' => repository)
               end
        fake_runner.expect_call(['gh', 'repo', 'view', ORIGIN_URL, '--json', 'nameWithOwner'], stdout: view)
      end
    end
  end
end

# frozen_string_literal: true

require_relative 'checkout_calls'
require_relative 'contents_calls'
require_relative 'gate_calls'
require_relative 'script_runs'
require_relative '../../lib/copilot_check/rereview'
require_relative '../../lib/copilot_check/setup'
require_relative '../../lib/copilot_check/threads_command'

module CopilotCheck
  module Testing
    # The calls setup, threads and rereview make, and their answers, on
    # sgbett/dotfiles-claude as recorded where it can; a spec changes only
    # what its case needs.
    module ScriptCalls
      include CheckoutCalls
      include ContentsCalls
      include GateCalls
      include ScriptRuns

      PR_VIEW_FIELDS = 'number,baseRefName,headRefName,isCrossRepository,isDraft,headRefOid,state,url'
      RUBRIC = ['gh', 'api', '--hostname', 'github.com', '-X', 'GET',
                "repos/#{GateCalls::HERE}/contents/.github/copilot-instructions.md", '-f', 'ref=master'].freeze
      BRANCH_CHECK = %w[git check-ref-format --branch master].freeze
      # #18's node id, as recorded.
      PULL_REQUEST_ID = 'PR_kwDOQzoXSs8AAAABOt1xEA'
      # When Copilot's latest recorded review of #18 came.
      REVIEWED_AT = '2026-11-12T20:23:51Z'

      # gh pr view's arguments: for pull request +number+ of this
      # repository, or the current branch's for nil.
      def pr_view_call(number = GateCalls::NUMBER)
        ['gh', 'pr', 'view', *([number.to_s, '-R', "github.com/#{GateCalls::HERE}"] if number), '--json',
         PR_VIEW_FIELDS]
      end

      # #18 as gh pr view recorded it, merged, with +fields+ changed.
      def pr_view_response(**fields)
        JSON.parse(fixture('pr-view/pull-request-18.json')).merge(fields.transform_keys(&:to_s))
      end

      # #18 as recorded but open, as a run needs it, with +fields+ changed.
      def open_pr_view_response(**fields)
        pr_view_response(state: 'OPEN', **fields)
      end

      def expect_repo_view
        fake_runner.expect_call(GateCalls::REPO_VIEW, stdout: fixture('repo-view/checkout.json'))
      end

      def expect_pr_view(number = GateCalls::NUMBER, response: open_pr_view_response, **result)
        fake_runner.expect_call(pr_view_call(number), stdout: as_json(response), **result)
      end

      # setup's look at the checkout its scripts run from, which in a unit
      # spec is a directory in no checkout at all.
      def expect_scripts_step
        fake_runner.expect_call(['git', '-C', scripts_skill_directory, 'rev-parse', '--show-toplevel'],
                                exit_status: 128, stderr: "fatal: not a git repository\n")
      end

      # A directory to stand for the running skill's, with nothing in it.
      def scripts_skill_directory
        @scripts_skill_directory ||= sandbox.path('scripts', 'skills', 'copilot-check').tap do |path|
          FileUtils.mkdir_p(path)
        end
      end

      def expect_latest_review(response = fixture('graphql/latest-review-18.json'), number: GateCalls::NUMBER,
                               **result)
        fake_runner.expect_call(GateCalls::GRAPHQL,
                                stdin: graphql_request(LatestReview::QUERY, LatestReview.variables(HERE, number)),
                                stdout: as_json(response), **result)
      end

      # A latest review query answer: Copilot's review submitted at
      # +submitted_at+ by +author+, or none for nil.
      def latest_review_response(submitted_at, author: Copilot::BOT_ID)
        nodes = submitted_at ? [{ 'submittedAt' => submitted_at, 'author' => { 'id' => author } }] : []
        { 'data' => { 'repository' => { 'pullRequest' => { 'reviews' => { 'nodes' => nodes } } } } }
      end

      def expect_threads(response, number: GateCalls::NUMBER, **result)
        fake_runner.expect_call(GateCalls::GRAPHQL,
                                stdin: graphql_request(Threads::QUERY, Threads.variables(HERE, number)),
                                stdout: as_json(response), **result)
      end

      # The re-read of review thread +id+ just before it is resolved.
      def expect_thread_reread(id, response)
        fake_runner.expect_call(GateCalls::GRAPHQL, stdin: graphql_request(ThreadResolution::THREAD, 'id' => id),
                                                    stdout: as_json(response))
      end

      # A thread re-read's answer: thread +id+, unresolved and last
      # answered by us unless +fields+ say otherwise.
      def thread_reread_response(id, resolved: false, ours: true)
        node = { 'id' => id, 'isResolved' => resolved,
                 'first' => { 'nodes' => [{ 'author' => { '__typename' => 'Bot', 'login' => Copilot::COMMENT_LOGIN,
                                                          'id' => Copilot::BOT_ID } }] },
                 'last' => { 'nodes' => [{ 'viewerDidAuthor' => ours }] } }
        { 'data' => { 'node' => node } }
      end

      def expect_resolve(id, resolved: true, **result)
        fake_runner.expect_call(GateCalls::GRAPHQL, stdin: graphql_request(ThreadResolution::RESOLVE, 'id' => id),
                                                    stdout: as_json(resolve_response(id, resolved: resolved)),
                                                    **result)
      end

      def resolve_response(id, resolved: true)
        { 'data' => { 'resolveReviewThread' => { 'thread' => { 'id' => id, 'isResolved' => resolved } } } }
      end

      def expect_pull_request_id
        fake_runner.expect_call(GateCalls::GRAPHQL,
                                stdin: graphql_request(ReviewRequest::PULL_REQUEST_ID,
                                                       PullRequestQuery.variables(HERE, GateCalls::NUMBER)),
                                stdout: fixture('graphql/pull-request-id-18.json'))
      end

      def request_reviews_request
        graphql_request(ReviewRequest::MUTATION, 'pullRequestId' => PULL_REQUEST_ID, 'botIds' => [Copilot::BOT_ID])
      end

      def expect_request_reviews(response, **result)
        fake_runner.expect_call(GateCalls::GRAPHQL, stdin: request_reviews_request, stdout: as_json(response),
                                                    **result)
      end

      # A GraphQL answer with errors saying each of +messages+, which gh
      # prints on stdout as it exits 1.
      def graphql_errors(*messages)
        { 'data' => nil, 'errors' => messages.map { |message| { 'message' => message } } }
      end
    end
  end
end

# frozen_string_literal: true

module CopilotCheck
  module Testing
    # rereview request's call to requestCopilotCodeReview on #18, and its
    # answers, synthesised as no mutation is recorded. ScriptCalls includes
    # it.
    module ReviewRequestCalls
      def copilot_review_request
        graphql_request(ReviewRequest::MUTATION, 'pullRequestId' => ScriptCalls::PULL_REQUEST_ID)
      end

      def expect_copilot_review_request(response, **result)
        fake_runner.expect_call(GateCalls::GRAPHQL, stdin: copilot_review_request, stdout: as_json(response), **result)
      end

      # +success+ and +failure_reason+ as given, naming +pull_request+, or
      # no pull request for nil.
      def copilot_review_answer(success, failure_reason = nil, pull_request: ScriptCalls::PULL_REQUEST_ID)
        { 'data' => { 'requestCopilotCodeReview' => {
          'success' => success, 'failureReason' => failure_reason,
          'pullRequest' => pull_request && { 'id' => pull_request }
        } } }
      end
    end
  end
end

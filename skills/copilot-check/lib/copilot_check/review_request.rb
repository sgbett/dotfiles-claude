# frozen_string_literal: true

require_relative 'checkout_repository'
require_relative 'pull_request_query'
require_relative 'reasons'

module CopilotCheck
  # `rereview request --pr N [--dry-run]`: Phase 5 step 2. Asks for Copilot's
  # review through GraphQL's requestCopilotCodeReview rather than
  # requestReviews: a ruleset that reviews every push requests one moments
  # after the push, racing ours, and requestReviews then refuses ours with an
  # error that doesn't say why. This mutation documents that case, answering
  # failureReason REQUEST_CONFLICT, a review underway, and requests a new
  # review once Copilot's last one has completed. Any other failureReason it
  # documents stops the run naming it. A dry run finds the pull request and
  # requests nothing.
  class ReviewRequest
    PULL_REQUEST_ID = File.read(File.join(__dir__, 'pull_request_id.graphql'))
    MUTATION = File.read(File.join(__dir__, 'request_copilot_code_review.graphql'))
    REQUESTED = 'requested'
    UNDERWAY = 'underway'
    SKIPPED = 'skipped'
    REQUEST_CONFLICT = 'REQUEST_CONFLICT'
    # The rest of GitHub's CopilotCodeReviewRequestReason. The stop's message
    # names the reason, so only one checked against this list may reach it.
    REFUSALS = %w[ACTOR_INELIGIBLE REPOSITORY_INELIGIBLE APP_NOT_INSTALLED NO_QUOTA_REMAINING
                  LICENSED_ORGANIZATION_UNAVAILABLE].freeze

    # +options+ are RereviewArguments' Options.
    def initialize(options, runner:)
      @options = options
      @runner = runner
    end

    def call
      repository = CheckoutRepository.resolve(@runner)
      @github = SkillSupport::Gh.new(host: repository.host, runner: @runner)
      id = pull_request_id(repository.name_with_owner)
      @options.dry_run ? outcome(SKIPPED) : request(id)
    end

    private

    def pull_request_id(repository)
      data = @github.graphql(PULL_REQUEST_ID, PullRequestQuery.variables(repository, @options.pr))
      SkillSupport::Identifiers.node_id!(data.dig('repository', 'pullRequest', 'id'))
    end

    def request(id)
      answer = @github.graphql(MUTATION, 'pullRequestId' => id)['requestCopilotCodeReview']
      unexpected('gave no answer') unless answer.is_a?(Hash)
      unexpected("didn't answer with the pull request") unless names_pull_request?(answer, id)

      success, reason = answer.values_at('success', 'failureReason')
      success == true ? requested(reason) : failed(success, reason)
    end

    # A failed request may leave pullRequest out; a successful one must name
    # the pull request it was sent.
    def names_pull_request?(answer, id)
      named = answer.dig('pullRequest', 'id')
      named == id || (named.nil? && answer['success'] != true)
    end

    def requested(reason)
      unexpected('succeeded, yet gave a failureReason') unless reason.nil?

      outcome(REQUESTED)
    end

    def failed(success, reason)
      unexpected('answered neither success nor failure') unless success == false
      return outcome(UNDERWAY, session_only: { failure_reason: REQUEST_CONFLICT }) if reason == REQUEST_CONFLICT
      return refused(reason) if REFUSALS.include?(reason)

      unexpected('failed without a failureReason it documents')
    end

    def refused(reason)
      Reasons.stop_naming(Reasons::COPILOT_REQUEST_REFUSED, reason, pull_request: { number: @options.pr })
    end

    def unexpected(problem)
      raise SkillSupport::UnexpectedResponse, "requestCopilotCodeReview #{problem}"
    end

    def outcome(review_request, **fields)
      SkillSupport::Outcome.proceed(pull_request: { number: @options.pr }, review_request: review_request,
                                    dry_run: @options.dry_run, **fields)
    end
  end
end

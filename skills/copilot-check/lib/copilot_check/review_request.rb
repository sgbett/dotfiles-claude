# frozen_string_literal: true

require_relative 'checkout_repository'
require_relative 'copilot'
require_relative 'pull_request_query'

module CopilotCheck
  # `rereview request --pr N [--dry-run]`: Phase 5 step 2. Asks Copilot for
  # a new review through GraphQL's requestReviews, by its bot id, with
  # union: true, which keeps the reviewers already requested; REST's
  # requested_reviewers drops a request for Copilot without a word. The
  # mutation's answer must name the pull request. A dry run finds the pull
  # request and requests nothing.
  class ReviewRequest
    PULL_REQUEST_ID = File.read(File.join(__dir__, 'pull_request_id.graphql'))
    MUTATION = File.read(File.join(__dir__, 'request_reviews.graphql'))
    REQUESTED = 'requested'
    UNDERWAY = 'underway'
    SKIPPED = 'skipped'
    # GitHub doesn't document the error requestReviews gives while Copilot is
    # already reviewing, so every error saying "already" is read as that, as
    # the skill always has. A misreading costs no more than the watcher's
    # timeout, which reports the missing review.
    ALREADY = /\balready\b/i

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
      data = @github.graphql(MUTATION, 'pullRequestId' => id, 'botIds' => [Copilot::BOT_ID])
      return outcome(REQUESTED) if data.dig('requestReviews', 'pullRequest', 'id') == id

      raise SkillSupport::UnexpectedResponse, "requestReviews didn't answer with the pull request"
    rescue SkillSupport::GraphqlError => e
      raise unless underway?(e.errors)

      outcome(UNDERWAY, session_only: { error: e.message })
    end

    def underway?(errors)
      messages = Array(errors).map { |error| error['message'] if error.is_a?(Hash) }
      !messages.empty? && messages.all? { |message| ALREADY.match?(message.to_s) }
    end

    def outcome(review_request, **fields)
      SkillSupport::Outcome.proceed(pull_request: { number: @options.pr }, review_request: review_request,
                                    dry_run: @options.dry_run, **fields)
    end
  end
end

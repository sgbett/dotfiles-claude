# frozen_string_literal: true

require_relative 'checkout_repository'
require_relative 'latest_review'
require_relative 'reasons'
require_relative 'stop'
require_relative 'timestamp'

module CopilotCheck
  # `rereview watch --pr N --since TIMESTAMP`: Phase 5 step 3, which the
  # lead runs in the background. Polls Copilot's latest review (LatestReview)
  # until one newer than the high-water mark TIMESTAMP comes, giving its
  # submittedAt, or for 15 minutes, which stops as copilot_timeout. Copilot
  # usually takes about 3 minutes. A poll that fails is counted and retried,
  # never read as a review; one that finds the latest review under another
  # id stops.
  class ReviewWatch
    # +timeout+ and +interval+ are in seconds, +clock+ gives a monotonic
    # time in seconds, and +sleeper+ waits the seconds it is given.
    Timing = Struct.new(:timeout, :interval, :clock, :sleeper, keyword_init: true)
    TIMING = Timing.new(timeout: 15 * 60, interval: 40,
                        clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) },
                        sleeper: ->(seconds) { sleep(seconds) }).freeze

    # +options+ are RereviewArguments' Options.
    def initialize(options, runner:, timing: TIMING)
      @options = options
      @runner = runner
      @timing = timing
      @failed_polls = 0
    end

    def call
      repository = CheckoutRepository.resolve(@runner)
      @repository = repository.name_with_owner
      @latest = LatestReview.new(SkillSupport::Gh.new(host: repository.host, runner: @runner))
      watch
    rescue Stop => e
      Reasons.stop(e.reason, pull_request: { number: @options.pr })
    end

    private

    def watch
      deadline = @timing.clock.call + @timing.timeout
      until @timing.clock.call >= deadline
        submitted_at = poll
        return ready(submitted_at) if submitted_at

        @timing.sleeper.call(@timing.interval)
      end
      timed_out
    end

    # The submittedAt of Copilot's latest review when it is newer than the
    # mark, else nil.
    def poll
      submitted_at = @latest.submitted_at(@repository, @options.pr)
      submitted_at if submitted_at && Timestamp.after?(submitted_at, @options.since)
    rescue SkillSupport::Error => e
      @failed_polls += 1
      @error = e.message
      nil
    end

    def ready(submitted_at)
      SkillSupport::Outcome.proceed(pull_request: { number: @options.pr }, submitted_at: submitted_at)
    end

    def timed_out
      fields = { pull_request: { number: @options.pr }, failed_polls: @failed_polls }
      fields[:session_only] = { error: @error } if @error
      Reasons.stop(Reasons::COPILOT_TIMEOUT, **fields)
    end
  end
end

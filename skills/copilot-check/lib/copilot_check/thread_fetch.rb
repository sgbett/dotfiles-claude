# frozen_string_literal: true

require_relative 'checkout_repository'
require_relative 'output_file'
require_relative 'reasons'
require_relative 'stop'
require_relative 'threads'

module CopilotCheck
  # `threads fetch --pr N --bodies-dir DIR`: Phase 2a. What of Copilot's
  # review is still to do, from one fresh fetch with every stop 2a makes
  # (Threads): its threads, by their ids and location, and its reviews, by
  # id. Each one's body, Copilot's text, goes to a file in DIR for the
  # verifiers, never to stdout, and a thread's path is printed only as
  # GitHub text.
  class ThreadFetch
    # +options+ are ThreadsArguments' Options.
    def initialize(options, runner:)
      @options = options
      @runner = runner
    end

    def call
      result = fetch
      @directory = OutputFile.directory(@options.bodies_dir)
      SkillSupport::Outcome.proceed(pull_request: { number: @options.pr },
                                    todo_threads: result.todo_threads.map { |thread| thread_entry(thread) },
                                    todo_reviews: result.todo_reviews.map { |review| review_entry(review) })
    rescue Stop => e
      Reasons.stop(e.reason, pull_request: { number: @options.pr })
    end

    private

    def fetch
      repository = CheckoutRepository.resolve(@runner)
      Threads.new(SkillSupport::Gh.new(host: repository.host, runner: @runner))
             .fetch(repository.name_with_owner, @options.pr)
    end

    # +line+ is nil, and the code at +original_line+ in +original_commit+,
    # once later commits have moved it.
    def thread_entry(thread)
      comment_id = SkillSupport::Identifiers.comment_id!(thread.comment_id)
      { thread_id: SkillSupport::Identifiers.node_id!(thread.thread_id), comment_id: comment_id,
        outdated: outdated(thread), line: line(thread.line), original_line: line(thread.original_line),
        original_commit: thread.original_commit && SkillSupport::Identifiers.commit_sha!(thread.original_commit),
        body_file: body_file("thread-#{comment_id}.md", thread.body), github_text: { path: path(thread) } }
    end

    def review_entry(review)
      { review_id: review.review_id, body_file: body_file("review-#{review.review_id}.md", review.body) }
    end

    # Writes +body+ to the file +name+ in the bodies directory and returns
    # its name.
    def body_file(name, body)
      OutputFile.write(File.join(@directory, name), body.to_s)
      name
    end

    def outdated(thread)
      return thread.outdated if [true, false].include?(thread.outdated)

      raise SkillSupport::UnexpectedResponse, 'a review thread came back without isOutdated'
    end

    def line(line)
      return line if line.nil? || (line.is_a?(Integer) && line.positive?)

      raise SkillSupport::UnexpectedResponse, "a review thread's line is not a line number"
    end

    def path(thread)
      return thread.path if thread.path.is_a?(String) && !thread.path.empty?

      raise SkillSupport::UnexpectedResponse, 'a review thread came back without its path'
    end
  end
end

# frozen_string_literal: true

require_relative 'body_files'
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
  # verifiers, never to stdout, as does an outdated thread's file as it
  # stood at the commit Copilot commented on, read through GitHub so that
  # no path reaches a command line; a thread's path is printed only as
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
      @repository = CheckoutRepository.resolve(@runner)
      @github = SkillSupport::Gh.new(host: @repository.host, runner: @runner)
      Threads.new(@github).fetch(@repository.name_with_owner, @options.pr)
    end

    # +line+ is nil, and the code at +original_line+ in +original_file+,
    # once later commits have moved it.
    def thread_entry(thread)
      comment_id = SkillSupport::Identifiers.comment_id!(thread.comment_id)
      path = path(thread)
      { thread_id: SkillSupport::Identifiers.node_id!(thread.thread_id), comment_id: comment_id,
        outdated: outdated(thread), line: line(thread.line), original_line: line(thread.original_line),
        **original(thread, comment_id, path), body_file: body_file(BodyFiles.thread(comment_id), thread.body),
        github_text: { path: path } }
    end

    # The commit an outdated thread's code is in, and the file as it stood
    # there.
    def original(thread, comment_id, path)
      commit = thread.original_commit && SkillSupport::Identifiers.commit_sha!(thread.original_commit)
      { original_commit: commit, original_file: (original_file(comment_id, path, commit) if thread.outdated) }
    end

    def review_entry(review)
      { review_id: review.review_id, body_file: body_file(BodyFiles.review(review.review_id), review.body) }
    end

    # Writes +body+ to the file +name+ in the bodies directory and returns
    # its name.
    def body_file(name, body)
      OutputFile.write(File.join(@directory, name), body.to_s)
      name
    end

    # Writes the file at +path+ as it stood at +commit+ to the bodies
    # directory and returns its name, or nil when GitHub says the path
    # didn't exist there.
    def original_file(comment_id, path, commit)
      unless commit
        raise SkillSupport::UnexpectedResponse, "outdated review comment #{comment_id} has no original commit"
      end

      text = original_text(comment_id, path, commit)
      body_file(BodyFiles.original(comment_id), text) unless text.nil?
    end

    # The file at +path+ as it stood at +commit+, or nil when the path didn't
    # exist there. The path is GitHub text, so a failure names the comment
    # instead.
    def original_text(comment_id, path, commit)
      text = SkillSupport::RepositoryFiles.new(@github).read(@repository.name_with_owner, path, ref: commit)
      text.is_a?(Array) ? not_a_file!(comment_id) : text
    rescue SkillSupport::UnexpectedResponse
      not_a_file!(comment_id)
    end

    def not_a_file!(comment_id)
      raise SkillSupport::UnexpectedResponse, "review comment #{comment_id}'s path isn't a file of at most 1 MB at " \
                                              'its original commit'
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

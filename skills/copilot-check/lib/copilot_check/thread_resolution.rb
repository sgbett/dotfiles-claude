# frozen_string_literal: true

require_relative 'checkout_repository'
require_relative 'reasons'
require_relative 'stop'
require_relative 'threads'
require_relative 'todo_selection'

module CopilotCheck
  # `threads resolve --pr N [--dry-run]`: Phase 4 step 4, once the lead has
  # replied. From one fresh fetch with 2a's stops, it resolves each thread
  # Copilot started that is unresolved and last answered by us
  # (TodoSelection.resolvable?). Each is read again just before its
  # resolveReviewThread and resolved only if it still is one, so a thread
  # someone has answered or resolved since is left alone, under `changed`,
  # for the next round to fetch; the mutation's answer must show it
  # resolved. A dry run gives the threads it would resolve and resolves none.
  class ThreadResolution
    THREAD = File.read(File.join(__dir__, 'review_thread.graphql'))
    RESOLVE = File.read(File.join(__dir__, 'resolve_review_thread.graphql'))

    # +options+ are ThreadsArguments' Options.
    def initialize(options, runner:)
      @options = options
      @runner = runner
    end

    def call
      ids = resolvable
      resolved, changed = @options.dry_run ? [ids, []] : ids.partition { |id| resolve_unchanged(id) }
      SkillSupport::Outcome.proceed(pull_request: { number: @options.pr }, resolved: resolved, changed: changed,
                                    dry_run: @options.dry_run)
    rescue Stop => e
      Reasons.stop(e.reason, pull_request: { number: @options.pr })
    end

    private

    # The ids of the threads to resolve, from a fresh fetch.
    def resolvable
      repository = CheckoutRepository.resolve(@runner)
      @github = SkillSupport::Gh.new(host: repository.host, runner: @runner)
      Threads.new(@github).fetch(repository.name_with_owner, @options.pr).resolvable_threads
             .map { |id| SkillSupport::Identifiers.node_id!(id) }
    end

    # Resolves thread +id+ if it is still one to resolve, and says whether
    # it did.
    def resolve_unchanged(id)
      node = @github.graphql(THREAD, 'id' => id)['node']
      return false unless node.is_a?(Hash) && node['id'] == id && TodoSelection.resolvable?(node)

      thread = @github.graphql(RESOLVE, 'id' => id).dig('resolveReviewThread', 'thread')
      return true if thread.is_a?(Hash) && thread['id'] == id && thread['isResolved'] == true

      raise SkillSupport::UnexpectedResponse, "review thread #{id} doesn't read back as resolved"
    end
  end
end

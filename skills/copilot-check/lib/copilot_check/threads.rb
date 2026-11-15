# frozen_string_literal: true

require_relative 'copilot'
require_relative 'reasons'
require_relative 'stop'
require_relative 'todo_selection'

module CopilotCheck
  # Phase 2a's fetch, in one query with Copilot's latest review (Phase 0's)
  # and the head it must be of for 2a to converge: a pull request's review
  # threads, Copilot's reviews and the pull request's comments, what of them
  # is still to do, and which threads an answer of ours has left to resolve
  # (TodoSelection). Where 2a stops, this raises Stop rather than guess: a
  # list longer than its one page, or a sign that the filters no longer
  # recognise Copilot. GraphQL errors raise too, even beside data.
  class Threads
    QUERY = File.read(File.join(__dir__, 'threads.graphql'))
    PAGED_LISTS = %w[reviews comments reviewThreads].freeze

    # +comments+ counts the review's inline comments; +commit+ is the oid of
    # the commit it reviewed.
    LatestReview = Struct.new(:submitted_at, :comments, :commit, keyword_init: true)
    # +head+ is the oid of the pull request's head commit; +latest_review+
    # is nil when Copilot hasn't reviewed the pull request; +todo_threads+,
    # +todo_reviews+ and +resolvable_threads+ are TodoSelection's.
    Result = Struct.new(:head, :latest_review, :todo_threads, :todo_reviews, :resolvable_threads,
                        keyword_init: true) do
      # Whether Copilot's latest review is of the head; false when it hasn't
      # reviewed.
      def copilot_on_head?
        !latest_review.nil? && latest_review.commit == head
      end
    end

    def self.variables(repository, number)
      owner, name = SkillSupport::Identifiers.repository!(repository).split('/')
      { 'owner' => owner, 'name' => name, 'number' => SkillSupport::Identifiers.issue_number!(number),
        'copilot' => Copilot::REVIEWER_LOGIN }
    end

    # +github+ is the SkillSupport::Gh for the repository's host.
    def initialize(github)
      @github = github
    end

    # The Result for pull request +number+ of +repository+ ("owner/repo").
    def fetch(repository, number)
      pull_request = pull_request(@github.graphql(QUERY, self.class.variables(repository, number)))
      threads = nodes(pull_request, 'reviewThreads')
      reviews = nodes(pull_request, 'reviews')
      latest = latest_review(pull_request)
      copilot_ids!(reviews, threads)
      guard!(latest, threads)
      Result.new(head: SkillSupport::Identifiers.commit_sha!(pull_request['headRefOid']), latest_review: latest,
                 todo_threads: TodoSelection.threads(threads),
                 todo_reviews: TodoSelection.reviews(reviews, nodes(pull_request, 'comments')),
                 resolvable_threads: TodoSelection.resolvable(threads))
    end

    private

    def pull_request(data)
      node = data.dig('repository', 'pullRequest')
      raise SkillSupport::UnexpectedResponse, 'the thread fetch returned no pull request' unless node.is_a?(Hash)

      PAGED_LISTS.each { |list| SkillSupport::Pagination.ensure_complete!(node, list) }
      node
    rescue SkillSupport::IncompleteResults
      raise Stop, Reasons::THREADS_OVERFLOW
    end

    def nodes(pull_request, list)
      nodes = pull_request.dig(list, 'nodes')
      return nodes if nodes.is_a?(Array) && nodes.all?(Hash)

      raise SkillSupport::UnexpectedResponse, "the thread fetch's #{list} came back without their nodes"
    end

    # Copilot's latest review, nil when it hasn't reviewed, as when the
    # latest under its login isn't a bot's.
    def latest_review(pull_request)
      node = nodes(pull_request, 'latest').first
      return unless Copilot.bot_review?(node)

      copilot!(node)
      comments = node.dig('comments', 'totalCount')
      unless comments.is_a?(Integer)
        raise SkillSupport::UnexpectedResponse, "Copilot's latest review came back without its comment count"
      end

      LatestReview.new(submitted_at: node['submittedAt'], comments: comments, commit: node.dig('commit', 'oid'))
    end

    # Every review a bot wrote that the login filter returned must carry
    # Copilot's id, as must a thread a bot started under Copilot's comment
    # login. Any other author, such as the organisation that holds the bare
    # login, isn't Copilot, and TodoSelection leaves its reviews and threads
    # out.
    def copilot_ids!(reviews, threads)
      comments = threads.map { |thread| TodoSelection.first_comment(thread) }
                        .select { |comment| Copilot.comment_login?(comment) }
      (reviews.select { |review| Copilot.bot_review?(review) } + comments).each { |node| copilot!(node) }
    end

    # 2a's guard: when Copilot's latest review made inline comments, some
    # thread, resolved or not, must be recognised as Copilot's.
    def guard!(latest, threads)
      return unless latest&.comments&.positive? && threads.none? { |thread| TodoSelection.copilot_started?(thread) }

      raise Stop, Reasons::COPILOT_UNRECOGNISED
    end

    def copilot!(node)
      raise Stop, Reasons::COPILOT_ID_CHANGED unless Copilot.authored?(node)
    end
  end
end

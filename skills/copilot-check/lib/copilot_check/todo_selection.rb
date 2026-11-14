# frozen_string_literal: true

require_relative 'copilot'

module CopilotCheck
  # Phase 2a's selection of what is still to do, from the thread fetch's
  # GraphQL nodes: the threads Copilot started that are unresolved and not
  # last answered by us, and Copilot's reviews that no comment of ours marks
  # answered. Anything GitHub leaves unsaid counts against an answer.
  module TodoSelection
    # Phase 4 ends its answer to review-body findings with one of these for
    # each review it read.
    ANSWERED_MARKER = /<!-- copilot-check:answered ([0-9]+) -->/

    # A thread still to do, with 2a's fields. +comment_id+ is its first
    # comment's REST id, which a reply's in_reply_to takes. An outdated
    # thread's +line+ is nil once later commits move its code, which is then
    # at +original_line+ in +original_commit+. +path+ and +body+ are GitHub
    # text.
    TodoThread = Struct.new(:thread_id, :outdated, :comment_id, :path, :line, :original_line, :original_commit,
                            :body, keyword_init: true)
    # A Copilot review still to do. +body+ is GitHub text.
    TodoReview = Struct.new(:review_id, :body, keyword_init: true)

    module_function

    # The TodoThreads among review thread nodes +threads+. A stranger's
    # reply never counts as an answer.
    def threads(threads)
      threads.select { |thread| to_do?(thread) }.map { |thread| todo_thread(thread) }
    end

    # The TodoReviews among Copilot's review nodes +reviews+, given the pull
    # request's comment nodes +comments+, of which only ours count.
    def reviews(reviews, comments)
      answered = answered_ids(comments)
      reviews.map { |review| TodoReview.new(review_id: review_id(review), body: review['body']) }
             .reject { |review| answered.include?(review.review_id) }
    end

    # Whether Copilot started review thread node +thread+.
    def copilot_started?(thread)
      Copilot.authored?(first_comment(thread))
    end

    def first_comment(thread)
      thread.dig('first', 'nodes')&.first
    end

    def to_do?(thread)
      answered = thread.dig('last', 'nodes')&.first&.fetch('viewerDidAuthor', nil) == true
      thread['isResolved'] != true && copilot_started?(thread) && !answered
    end

    def todo_thread(thread)
      comment = first_comment(thread)
      TodoThread.new(thread_id: thread['id'], outdated: thread['isOutdated'], comment_id: comment['databaseId'],
                     path: comment['path'], line: comment['line'], original_line: comment['originalLine'],
                     original_commit: comment.dig('originalCommit', 'oid'), body: comment['body'])
    end

    def answered_ids(comments)
      comments.select { |comment| comment['viewerDidAuthor'] == true }
              .flat_map { |comment| comment['body'].to_s.scan(ANSWERED_MARKER).map { |(id)| Integer(id, 10) } }
    end

    def review_id(review)
      id = review['databaseId']
      return id if id.is_a?(Integer)

      raise SkillSupport::UnexpectedResponse, 'a Copilot review came back without its databaseId'
    end

    private_class_method :to_do?, :todo_thread, :answered_ids, :review_id
  end
end

# frozen_string_literal: true

module CopilotCheck
  # The files `threads fetch` writes to a round's bodies directory, by name:
  # each body still to do, and an outdated thread's file as it stood when
  # Copilot commented. promote-check reads the reviews' back, as the run's
  # word that it read them.
  module BodyFiles
    module_function

    def thread(comment_id)
      "thread-#{comment_id}.md"
    end

    def review(review_id)
      "review-#{review_id}.md"
    end

    def original(comment_id)
      "original-#{comment_id}"
    end

    # The ids of +reviews+, TodoSelection's TodoReviews, whose file in
    # +directory+ holds the review's body as GitHub gives it now; none when
    # there is no directory. A file that can't be read holds no body.
    def current_reviews(directory, reviews)
      return [] if directory.nil?

      reviews.select { |todo| current?(File.join(directory, review(todo.review_id)), todo.body.to_s) }
             .map(&:review_id)
    end

    def current?(path, body)
      SkillSupport::WrittenFile.read(path) == body
    rescue SkillSupport::UnusableFile
      false
    end

    private_class_method :current?
  end
end

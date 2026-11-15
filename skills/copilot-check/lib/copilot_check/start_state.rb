# frozen_string_literal: true

require 'json'

module CopilotCheck
  # The start file isn't one promote-check can take.
  class UnusableStartFile < SkillSupport::UnusableFile; end

  # The run as it began: the start file setup writes
  # (PullRequestView::PullRequest#start_state), which promote-check reads.
  # What it records holds only for the repository it names, which the
  # reader checks first (#check_repository!).
  class StartState
    FLAGS = %w[isDraft chained].freeze

    # The start file at +path+, which must record pull request +number+, its
    # repository, whether it was a draft and whether /do chained the run.
    # Raises UnusableStartFile when the file isn't that JSON, or records
    # another pull request.
    def self.read(path, number)
      state = JSON.parse(SkillSupport::WrittenFile.read(path, error: UnusableStartFile))
      unless recorded?(state, number)
        raise UnusableStartFile, "#{path} doesn't record pull request #{number}'s number, repository, isDraft and " \
                                 'chained'
      end

      new(path, state)
    rescue JSON::ParserError
      raise UnusableStartFile, "#{path} isn't JSON"
    end

    def self.recorded?(state, number)
      state.is_a?(Hash) && state['number'] == number && state['repository'].is_a?(String) &&
        FLAGS.all? { |flag| [true, false].include?(state[flag]) }
    end

    private_class_method :recorded?

    def initialize(path, state)
      @path = path
      @state = state
    end

    # Raises UnusableStartFile when the file records a repository other than
    # +repository+, the CheckoutRepository::Repository promote-check runs in.
    def check_repository!(repository)
      return if @state['repository'].casecmp?(repository.argument)

      raise UnusableStartFile, "#{@path} records another repository than the checkout's"
    end

    # Whether the pull request was a draft when the run began.
    def draft?
      @state['isDraft']
    end

    # Whether /do chained the run, on the pull request it opened
    # (PullRequestArgument).
    def chained?
      @state['chained']
    end
  end
end

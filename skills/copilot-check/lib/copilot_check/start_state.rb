# frozen_string_literal: true

require 'json'

module CopilotCheck
  # The start file isn't one promote-check can take.
  class UnusableStartFile < SkillSupport::UnusableFile; end

  # The pull request as it was when the run began: the start file setup
  # writes (PullRequestView::PullRequest#start_state), which promote-check
  # reads.
  class StartState
    # The start file at +path+, which must record pull request +number+, its
    # repository and whether it was a draft. Raises UnusableStartFile when
    # the file isn't that JSON, or records another pull request.
    def self.read(path, number)
      state = JSON.parse(SkillSupport::WrittenFile.read(path, error: UnusableStartFile))
      unless state.is_a?(Hash) && state['number'] == number && state['repository'].is_a?(String) &&
             [true, false].include?(state['isDraft'])
        raise UnusableStartFile, "#{path} doesn't record pull request #{number}'s number, repository and isDraft"
      end

      new(path, state)
    rescue JSON::ParserError
      raise UnusableStartFile, "#{path} isn't JSON"
    end

    def initialize(path, state)
      @path = path
      @state = state
    end

    # Whether the pull request was a draft when the run began. Raises
    # UnusableStartFile when the file records a repository other than
    # +repository+, the CheckoutRepository::Repository promote-check runs in.
    def draft?(repository)
      unless @state['repository'].casecmp?(repository.argument)
        raise UnusableStartFile, "#{@path} records another repository than the checkout's"
      end

      @state['isDraft']
    end
  end
end

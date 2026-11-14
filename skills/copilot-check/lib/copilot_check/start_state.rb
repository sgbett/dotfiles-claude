# frozen_string_literal: true

require 'json'

module CopilotCheck
  # The start file isn't one promote-check can take.
  class UnusableStartFile < SkillSupport::UnusableFile; end

  # The pull request as it was when the run began: the file Phase 0 saved
  # from `gh pr view --json number,baseRefName,isCrossRepository,isDraft`.
  module StartState
    module_function

    # Whether pull request +number+ was a draft when the run began, from the
    # file at +path+. Raises UnusableStartFile when the file isn't that
    # JSON, or records another pull request.
    def draft?(path, number)
      state = JSON.parse(SkillSupport::WrittenFile.read(path, error: UnusableStartFile))
      unless state.is_a?(Hash) && state['number'] == number && [true, false].include?(state['isDraft'])
        raise UnusableStartFile, "#{path} doesn't record pull request #{number}'s number and isDraft"
      end

      state['isDraft']
    rescue JSON::ParserError
      raise UnusableStartFile, "#{path} isn't JSON"
    end
  end
end

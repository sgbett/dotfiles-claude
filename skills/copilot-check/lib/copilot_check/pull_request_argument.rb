# frozen_string_literal: true

require_relative 'reasons'
require_relative 'stop'

module CopilotCheck
  # The pull request the user named: the skill's argument, which the lead
  # writes to a file, so that the user's text reaches no command line.
  module PullRequestArgument
    NUMBER = /\A[1-9][0-9]{0,9}\z/

    module_function

    # The number the file at +path+ holds, or nil when it holds nothing but
    # white space, as when the user gave no argument. Raises Stop for
    # anything else, a pull request's URL included, as the repository is
    # always the checkout's.
    def read(path)
      text = SkillSupport::WrittenFile.read(path).strip
      return if text.empty?
      raise Stop, Reasons::NOT_A_PULL_REQUEST_NUMBER unless NUMBER.match?(text)

      Integer(text, 10)
    end
  end
end

# frozen_string_literal: true

require_relative 'reasons'
require_relative 'stop'

module CopilotCheck
  # The pull request the user named: the skill's argument, which the lead
  # writes to a file, so that the user's text reaches no command line. /do,
  # handing on the pull request it opened, adds chained after the number.
  module PullRequestArgument
    NUMBER = /\A[1-9][0-9]{0,9}\z/
    CHAINED = 'chained'

    module_function

    # The number the file at +path+ holds, nil when it holds nothing but
    # white space, as when the user gave no argument, and whether chained
    # follows it. Raises Stop for anything else, a pull request's URL
    # included, as the repository is always the checkout's, and for chained
    # alone, as /do always names the pull request it hands on.
    def read(path)
      number, *rest = SkillSupport::WrittenFile.read(path).split
      return [nil, false] if number.nil?
      raise Stop, Reasons::CHAINED_WITHOUT_NUMBER if number == CHAINED && rest.empty?
      raise Stop, Reasons::NOT_A_PULL_REQUEST_NUMBER unless NUMBER.match?(number) && [[], [CHAINED]].include?(rest)

      [Integer(number, 10), rest == [CHAINED]]
    end
  end
end

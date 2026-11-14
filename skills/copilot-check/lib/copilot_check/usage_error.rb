# frozen_string_literal: true

module CopilotCheck
  # promote-check was called with arguments it doesn't take.
  class UsageError < SkillSupport::Error
    USAGE = [
      'usage: promote-check check --pr <number> --rules-file <path> --start-file <path>',
      '                           --outcome converged|halted|timeout|stop|push-failed',
      '                           [--reviews-without-findings <review ids>]',
      '       promote-check verify --pr <number> --head <sha>',
      "where the rules file is the JSON the lead writes from the repository's rules, the start file is",
      "Phase 0's pr0.json, and <review ids>, comma-separated, are the to-do Copilot reviews the run read",
      'and found no finding in'
    ].join("\n").freeze

    def initialize
      super(USAGE)
    end
  end
end

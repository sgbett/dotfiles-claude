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
      super(self.class::USAGE)
    end
  end

  # setup was called with arguments it doesn't take.
  class SetupUsageError < UsageError
    USAGE = [
      'usage: setup --argument-file <path> --start-file <path> --rubric-file <path> [--accept-fork <sha>]',
      "where the argument file holds the skill's argument as the user gave it, a pull request number or",
      'nothing, and setup writes the start file and the rubric file, at absolute paths'
    ].join("\n").freeze
  end

  # threads was called with arguments it doesn't take.
  class ThreadsUsageError < UsageError
    USAGE = [
      'usage: threads fetch --pr <number> --bodies-dir <path>',
      '       threads resolve --pr <number> [--dry-run]',
      'where fetch writes each body still to do to a file in the directory at <path>, an absolute path'
    ].join("\n").freeze
  end

  # rereview was called with arguments it doesn't take.
  class RereviewUsageError < UsageError
    USAGE = [
      'usage: rereview request --pr <number> [--dry-run]',
      '       rereview watch --pr <number> --since <timestamp>',
      "where <timestamp> is the high-water mark, the submittedAt of Copilot's latest review when the",
      'round began, in ISO 8601 UTC'
    ].join("\n").freeze
  end
end

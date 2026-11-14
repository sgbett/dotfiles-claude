# frozen_string_literal: true

require_relative 'reasons'

module Do
  # The checkout /do's scripts live in (SkillSupport::ScriptsCheckout), which
  # `check` and `record` examine before going on, asking in /do's words.
  # When it is also the working directory's checkout, the lead builds in a
  # worktree.
  class ScriptsCheckout < SkillSupport::ScriptsCheckout
    SKILL_DIRECTORY = File.expand_path('../..', __dir__)

    # +skill_directory+ is the running skill's directory, symlinks resolved.
    def initialize(runner, skill_directory: SKILL_DIRECTORY)
      super(runner, skill_directory: skill_directory, reasons: Reasons)
    end
  end
end

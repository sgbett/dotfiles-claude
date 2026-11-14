# frozen_string_literal: true

require_relative 'rereview_arguments'
require_relative 'review_request'
require_relative 'review_watch'

module CopilotCheck
  # skills/copilot-check/bin/rereview: Copilot's next review. `request` asks
  # Copilot for one; `watch` waits for it.
  module Rereview
    COMMANDS = { 'request' => ReviewRequest, 'watch' => ReviewWatch }.freeze

    module_function

    def call(arguments, runner: SkillSupport::CommandRunner.new)
      options = RereviewArguments.parse(arguments)
      COMMANDS.fetch(options.command).new(options, runner: runner).call
    end
  end
end

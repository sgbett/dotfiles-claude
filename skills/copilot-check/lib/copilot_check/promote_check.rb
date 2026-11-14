# frozen_string_literal: true

require_relative 'promote_check_arguments'
require_relative 'promotion_gate'
require_relative 'ready_verification'

module CopilotCheck
  # skills/copilot-check/bin/promote-check: Phase 6's promotion gate. `check`
  # gives the verdict on marking a converged draft ready, PROMOTE or HOLD
  # with every reason; `verify`, once the lead has marked it ready, checks
  # that its head is still the commit `check` judged.
  module PromoteCheck
    COMMANDS = { 'check' => PromotionGate, 'verify' => ReadyVerification }.freeze

    module_function

    def call(arguments, runner: SkillSupport::CommandRunner.new)
      options = PromoteCheckArguments.parse(arguments)
      COMMANDS.fetch(options.command).new(options, runner: runner).call
    end
  end
end

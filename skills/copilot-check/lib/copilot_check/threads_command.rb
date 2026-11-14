# frozen_string_literal: true

require_relative 'thread_fetch'
require_relative 'thread_resolution'
require_relative 'threads_arguments'

module CopilotCheck
  # skills/copilot-check/bin/threads: Copilot's review threads. `fetch`
  # gives what of its review is still to do, each body in a file; `resolve`,
  # once the lead has replied, resolves the threads our replies answered.
  module ThreadsCommand
    COMMANDS = { 'fetch' => ThreadFetch, 'resolve' => ThreadResolution }.freeze

    module_function

    def call(arguments, runner: SkillSupport::CommandRunner.new)
      options = ThreadsArguments.parse(arguments)
      COMMANDS.fetch(options.command).new(options, runner: runner).call
    end
  end
end

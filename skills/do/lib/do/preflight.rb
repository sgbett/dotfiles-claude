# frozen_string_literal: true

require_relative 'facts'

module Do
  # preflight was called with arguments it doesn't take.
  class UsageError < SkillSupport::Error
    USAGE = 'usage: preflight facts <issue number | owner/repo#N | https://<host>/<owner>/<repo>/issues/<N>>'

    def initialize
      super(USAGE)
    end
  end

  # skills/do/bin/preflight: /do's pre-flight in two calls, with the
  # conventions, which are judgement, resolved by the lead between them.
  # `facts <issue>` reads the issue's facts; `check` validates the resolved
  # conventions and is still to be built.
  module Preflight
    module_function

    def call(arguments, runner: SkillSupport::CommandRunner.new)
      subcommand, *rest = arguments
      case subcommand
      when 'facts'
        raise UsageError unless rest.length == 1

        Facts.new(rest.first, runner: runner).call
      when 'check' then raise SkillSupport::Error, 'preflight check is not built yet'
      else raise UsageError
      end
    end
  end
end

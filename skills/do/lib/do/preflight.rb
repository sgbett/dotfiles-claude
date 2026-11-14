# frozen_string_literal: true

require_relative 'check'
require_relative 'facts'
require_relative 'usage_error'
require_relative 'written_file'

module Do
  # skills/do/bin/preflight: /do's pre-flight in two calls, with the
  # conventions, which are judgement, resolved by the lead between them.
  # `facts --argument-file <path>` reads the issue's facts; `check <issue>
  # ...` checks the conventions the lead resolved against GitHub and the
  # checkout.
  module Preflight
    ARGUMENT_FILE = '--argument-file'
    NEWLINE = "\n"

    module_function

    def call(arguments, runner: SkillSupport::CommandRunner.new)
      subcommand, *rest = arguments
      case subcommand
      when 'facts' then Facts.new(argument(rest), runner: runner).call
      when 'check' then Check.new(rest, runner: runner).call
      else raise UsageError
      end
    end

    # The issue as the user gave it, which the lead wrote to a file with the
    # Write tool, so that it never reaches a shell line. The file's one
    # trailing newline isn't the reference's; Facts judges the rest.
    def argument(rest)
      flag, path = rest
      raise UsageError unless rest.length == 2 && flag == ARGUMENT_FILE

      WrittenFile.read(WrittenFile.path!(:argument_file, path)).delete_suffix(NEWLINE)
    end

    private_class_method :argument
  end
end

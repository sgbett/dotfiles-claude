# frozen_string_literal: true

require_relative 'arguments'
require_relative 'usage_error'

module CopilotCheck
  # The arguments of threads, every one validated before anything else
  # runs: the subcommand, then its flags, each with its value, in any order.
  module ThreadsArguments
    SUBCOMMANDS = {
      'fetch' => { required: %w[--pr --bodies-dir] },
      'resolve' => { required: %w[--pr], dry_run: true }
    }.freeze

    Options = Struct.new(:command, :pr, :bodies_dir, :dry_run, keyword_init: true)

    module_function

    # The Options in +arguments+. Raises ThreadsUsageError for an unknown
    # subcommand, or a flag it doesn't take, repeats or lacks, and
    # InvalidIdentifier for a value that isn't valid.
    def parse(arguments)
      command, values, dry_run = Arguments.parse(arguments, SUBCOMMANDS, error: ThreadsUsageError)
      Options.new(command: command, dry_run: dry_run,
                  **values.to_h { |flag, value| [Arguments.option(flag), convert(flag, value)] })
    end

    def convert(flag, value)
      case flag
      when '--pr' then SkillSupport::Identifiers.issue_number!(value)
      when '--bodies-dir' then Arguments.output_path!(:bodies_dir, value)
      end
    end

    private_class_method :convert
  end
end

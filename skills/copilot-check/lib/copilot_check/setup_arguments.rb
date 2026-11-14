# frozen_string_literal: true

require_relative 'arguments'
require_relative 'usage_error'

module CopilotCheck
  # The arguments of setup, every one validated before anything else runs:
  # its flags, each with its value, in any order.
  module SetupArguments
    SPEC = { required: %w[--argument-file --start-file --rubric-file], optional: %w[--accept-fork] }.freeze

    Options = Struct.new(:argument_file, :start_file, :rubric_file, :accept_fork, keyword_init: true)

    module_function

    # The Options in +arguments+. Raises SetupUsageError for a flag setup
    # doesn't take, repeats or lacks, and InvalidIdentifier for a value that
    # isn't valid.
    def parse(arguments)
      values, = Arguments.values(arguments, SPEC, error: SetupUsageError)
      Options.new(**values.to_h { |flag, value| [Arguments.option(flag), convert(flag, value)] })
    end

    def convert(flag, value)
      case flag
      when '--argument-file' then SkillSupport::WrittenFile.path!(:argument_file, value)
      when '--accept-fork' then SkillSupport::Identifiers.commit_sha!(value)
      else Arguments.output_path!(Arguments.option(flag), value)
      end
    end

    private_class_method :convert
  end
end

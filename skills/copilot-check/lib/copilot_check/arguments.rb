# frozen_string_literal: true

module CopilotCheck
  # What every /copilot-check script's arguments have in common: a
  # subcommand where the script has them, then flags in any order, each with
  # its value, and --dry-run alone where the subcommand writes to GitHub.
  # Each script checks every value before anything else runs.
  module Arguments
    DRY_RUN = '--dry-run'

    module_function

    # The subcommand that +arguments+ begins with, the values of its flags
    # by flag, and whether --dry-run was given. +subcommands+ maps each
    # subcommand to its spec, as #values takes it. Raises +error+ for a
    # subcommand not among them.
    def parse(arguments, subcommands, error:)
      command, *flags = arguments
      spec = subcommands.fetch(command) { raise error }
      [command, *values(flags, spec, error: error)]
    end

    # The values in +flags+ by flag, and whether --dry-run was given:
    # +spec+ lists the flags the subcommand needs (:required) and may take
    # (:optional), and :dry_run is true where it takes --dry-run. Raises
    # +error+ for a flag it doesn't take, repeats or lacks. No value starts
    # with "-", so --dry-run is never one.
    def values(flags, spec, error:)
      dry_runs = flags.count(DRY_RUN)
      raise error if dry_runs > (spec[:dry_run] ? 1 : 0)

      values = pairs(flags - [DRY_RUN], error)
      raise error unless taken?(values.keys, spec)

      [values, dry_runs == 1]
    end

    # The option +flag+ sets: --rules-file sets rules_file.
    def option(flag)
      flag.delete_prefix('--').tr('-', '_').to_sym
    end

    # +value+, unchanged, when it is a path a script may write to: absolute,
    # so that nothing lands in the checkout's working tree by mistake.
    # Raises InvalidIdentifier of +kind+ otherwise.
    def output_path!(kind, value)
      path = SkillSupport::WrittenFile.path!(kind, value)
      raise SkillSupport::InvalidIdentifier.new(kind, value) unless File.absolute_path?(path)

      path
    end

    # +flags+, flag after value, by flag. Raises +error+ for a flag without
    # its value, or given twice.
    def pairs(flags, error)
      raise error if flags.length.odd?

      values = flags.each_slice(2).to_h
      raise error unless values.length * 2 == flags.length

      values
    end

    # Whether +flags+ are all the subcommand's required ones, and only those
    # it takes.
    def taken?(flags, spec)
      required = spec.fetch(:required, [])
      (flags - required - spec.fetch(:optional, [])).empty? && (required - flags).empty?
    end

    private_class_method :pairs, :taken?
  end
end

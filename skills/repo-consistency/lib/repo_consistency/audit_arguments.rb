# frozen_string_literal: true

require_relative 'usage_error'

module RepoConsistency
  # The arguments of git-settings, every one validated before anything else
  # runs: the subcommand audit, then repositories and flags in any order,
  # each flag with its value.
  module AuditArguments
    COMMAND = 'audit'
    FLAGS = %w[--template-dir --hostname].freeze
    DEFAULT_HOST = 'github.com'
    DEFAULT_TEMPLATE_DIRECTORY = File.expand_path('../../../../profiles/git-workflow', __dir__)

    Options = Struct.new(:repositories, :template_dir, :hostname, keyword_init: true)

    module_function

    # The Options in +arguments+. Raises UsageError for anything but audit,
    # or a flag it doesn't take, repeats or lacks the value of, and
    # InvalidIdentifier for a value that isn't valid. No repository at all
    # is a stop, not a usage error, so Audit reports it.
    def parse(arguments)
      command, *words = arguments
      raise UsageError unless command == COMMAND

      repositories, flags = split(words)
      Options.new(repositories: repositories.map { |name| SkillSupport::Identifiers.repository!(name) },
                  template_dir: template_directory(flags),
                  hostname: SkillSupport::Identifiers.host!(flags.fetch('--hostname', DEFAULT_HOST)))
    end

    # The repositories among +words+, and its flags by flag.
    def split(words)
      repositories = []
      flags = {}
      remaining = words.dup
      take(remaining.shift, remaining, repositories, flags) until remaining.empty?
      [repositories, flags]
    end

    def take(word, remaining, repositories, flags)
      if word.start_with?('-')
        raise UsageError if !FLAGS.include?(word) || flags.key?(word) || remaining.empty?

        flags[word] = remaining.shift
      else
        repositories << word
      end
    end

    def template_directory(flags)
      SkillSupport::WrittenFile.path!(:template_dir, flags.fetch('--template-dir', DEFAULT_TEMPLATE_DIRECTORY))
    end

    private_class_method :split, :take, :template_directory
  end
end

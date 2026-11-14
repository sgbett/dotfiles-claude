# frozen_string_literal: true

require 'open3'

module SkillSupport
  # Runs a child process from an argument array, never through a shell, with
  # an environment that keeps gh non-interactive, uncoloured and aimed only at
  # the host each call names.
  class CommandRunner
    Result = Struct.new(:stdout, :stderr, :exit_status, keyword_init: true) do
      def success?
        exit_status.zero?
      end
    end

    # GH_REPO and GH_HOST would retarget a call silently; the others page,
    # colour or fake a terminal. gh lets CLICOLOR_FORCE override NO_COLOR, which
    # would put escape codes into JSON.
    REMOVED_VARIABLES = %w[GH_REPO GH_HOST GH_FORCE_TTY GH_PAGER PAGER CLICOLOR_FORCE].freeze
    PINNED_VARIABLES = {
      'GH_PROMPT_DISABLED' => '1',
      'GH_NO_UPDATE_NOTIFIER' => '1',
      'NO_COLOR' => '1'
    }.freeze
    CHILD_ENVIRONMENT = REMOVED_VARIABLES.to_h { |name| [name, nil] }.merge(PINNED_VARIABLES).freeze
    SIGNAL_EXIT_BASE = 128

    # Runs +argv+ and returns its Result. +stdin+ is written to the child's
    # standard input, which is otherwise empty, so nothing can wait on a
    # terminal. Raises ArgumentError for anything but a non-empty array of
    # strings, and CommandNotFound when argv[0] can't be found.
    def run(argv, stdin: nil)
      command, *arguments = validate(argv)
      # The [command, argv0] pair makes spawn exec directly even when argv has
      # one element, which it would otherwise hand to a shell.
      stdout, stderr, status = Open3.capture3(CHILD_ENVIRONMENT, [command, command], *arguments,
                                              stdin_data: stdin.to_s, binmode: true)
      Result.new(stdout: as_utf8(stdout), stderr: as_utf8(stderr), exit_status: exit_status(status))
    rescue Errno::ENOENT
      raise CommandNotFound, command
    end

    private

    def validate(argv)
      unless argv.is_a?(Array) && !argv.empty? && argv.all?(String) && !argv.first.empty?
        raise ArgumentError, 'a command is a non-empty array of strings, never a shell string'
      end

      argv
    end

    def as_utf8(output)
      output.force_encoding(Encoding::UTF_8)
    end

    def exit_status(status)
      status.exitstatus || (SIGNAL_EXIT_BASE + status.termsig)
    end
  end
end

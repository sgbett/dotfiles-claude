# frozen_string_literal: true

module Do
  # git answered in a way its caller doesn't handle. The message names the
  # arguments with any URL's credentials masked, as a push URL can carry a
  # token and a tool failure prints the message.
  class GitError < SkillSupport::Error
    def initialize(arguments, result)
      printed = arguments.map { |argument| SkillSupport::RemoteUrl.redacted(argument) }.join(' ')
      super("git #{printed} exited #{result.exit_status}: #{result.stderr.strip}")
    end
  end

  # Runs git through a CommandRunner, in the working directory unless the
  # arguments start with -C.
  class Git
    # A checkout's configuration can name a command for git to run: an
    # fsmonitor, which reading the working tree starts, or hooks. Pre-flight
    # only reads, so the calls that could start one put these first.
    NO_FSMONITOR = %w[-c core.fsmonitor=false].freeze
    NO_HOOKS_OR_FSMONITOR = ['-c', 'core.hooksPath=/dev/null', *NO_FSMONITOR].freeze

    def initialize(runner)
      @runner = runner
    end

    # The Result of `git ARGUMENTS`, given +stdin+ on its standard input,
    # whose exit status must be in +allowed+.
    def run(*arguments, allowed: [0], stdin: nil)
      result = @runner.run(['git', *arguments], stdin: stdin)
      raise GitError.new(arguments, result) unless allowed.include?(result.exit_status)

      result
    end

    # What a call that must succeed printed, as valid UTF-8.
    def output(*arguments, stdin: nil)
      run(*arguments, stdin: stdin).stdout.scrub
    end

    # The first line a call printed when it exits 0, or nil when it exits 1,
    # as `git config --get` and `git rev-parse --verify --quiet` do for
    # nothing found.
    def line_or_nil(*arguments)
      result = run(*arguments, allowed: [0, 1])
      result.success? ? result.stdout.scrub.lines.first.to_s.chomp : nil
    end
  end
end

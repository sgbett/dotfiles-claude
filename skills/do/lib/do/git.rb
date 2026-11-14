# frozen_string_literal: true

module Do
  # git answered in a way its caller doesn't handle.
  class GitError < SkillSupport::Error
    def initialize(arguments, result)
      super("git #{arguments.join(' ')} exited #{result.exit_status}: #{result.stderr.strip}")
    end
  end

  # Runs git through a CommandRunner, in the working directory unless the
  # arguments start with -C.
  class Git
    def initialize(runner)
      @runner = runner
    end

    # The Result of `git ARGUMENTS`, whose exit status must be in +allowed+.
    def run(*arguments, allowed: [0])
      result = @runner.run(['git', *arguments])
      raise GitError.new(arguments, result) unless allowed.include?(result.exit_status)

      result
    end

    # What a call that must succeed printed, as valid UTF-8.
    def output(*arguments)
      run(*arguments).stdout.scrub
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

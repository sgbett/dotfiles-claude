# frozen_string_literal: true

module SkillSupport
  # Runs a script's body and turns what it returns, or raises, into the script
  # contract: the Outcome's JSON on stdout and its exit code, or a tool failure
  # with a diagnostic on stderr and nothing on stdout.
  #
  #   exit SkillSupport::Cli.run('preflight', reasons: REASONS) { Preflight.new(ARGV).call }
  class Cli
    def self.run(program, reasons:, stdout: $stdout, stderr: $stderr, &body)
      new(program, reasons: reasons, stdout: stdout, stderr: stderr).run(&body)
    end

    # +reasons+ is the script's whole enum of stop and ask reasons; an
    # outcome carrying any other is a tool failure.
    def initialize(program, reasons:, stdout: $stdout, stderr: $stderr)
      @program = program
      @reasons = reasons.map(&:to_s)
      @stdout = stdout
      @stderr = stderr
    end

    # Yields for an Outcome and returns the exit code to exit with.
    def run
      outcome = yield
      check(outcome)
      @stdout.puts(outcome.to_json)
      outcome.exit_code
    rescue Error => e
      tool_failure(e.message)
    rescue StandardError, ScriptError => e
      tool_failure("#{e.class}: #{e.message}", e.backtrace)
    end

    private

    def check(outcome)
      raise ArgumentError, "#{@program} returned #{outcome.class}, not an Outcome" unless outcome.is_a?(Outcome)

      unknown = outcome.reasons - @reasons
      raise ArgumentError, "#{@program} has no reason #{unknown.join(', ')}" unless unknown.empty?
    end

    def tool_failure(message, backtrace = nil)
      @stderr.puts("#{@program}: tool failure: #{message}")
      @stderr.puts(backtrace) if backtrace
      Outcome::TOOL_FAILURE_EXIT_CODE
    end
  end
end

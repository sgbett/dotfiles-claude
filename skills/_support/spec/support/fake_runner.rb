# frozen_string_literal: true

module SkillSupport
  module Testing
    # Stands in for CommandRunner in unit specs. Each expected call gives the
    # exact argument array, the exact stdin (nil for none) and the recorded
    # output to answer with, in order. A call that differs, or that nothing
    # expected, fails the example.
    #
    #   fake_runner.expect_call(%w[gh api --hostname github.com -X GET repos/o/r/contents/x -f ref=master],
    #                           stdout: fixture('contents/x.json'))
    class FakeRunner
      Expectation = Struct.new(:argv, :stdin, :result, keyword_init: true)

      attr_reader :calls

      def initialize
        @expectations = []
        @calls = []
      end

      def expect_call(argv, stdin: nil, stdout: '', stderr: '', exit_status: 0)
        result = CommandRunner::Result.new(stdout: stdout, stderr: stderr, exit_status: exit_status)
        @expectations << Expectation.new(argv: argv, stdin: stdin, result: result)
        self
      end

      def run(argv, stdin: nil)
        @calls << { argv: argv, stdin: stdin }
        expected = @expectations.shift
        fail_example("unexpected command #{argv.inspect}") if expected.nil?
        check_call(expected, argv, stdin)
        expected.result
      end

      def verify!
        return if @expectations.empty?

        fail_example("expected commands never ran: #{@expectations.map(&:argv).inspect}")
      end

      private

      def check_call(expected, argv, stdin)
        fail_example("expected command #{expected.argv.inspect}\n got #{argv.inspect}") unless argv == expected.argv
        return if stdin == expected.stdin

        fail_example("stdin for #{argv.inspect}: expected #{expected.stdin.inspect}, got #{stdin.inspect}")
      end

      # ExpectationNotMetError is not a StandardError, so no rescue in the
      # code under test can swallow it.
      def fail_example(message)
        raise RSpec::Expectations::ExpectationNotMetError, "fake runner: #{message}"
      end
    end
  end
end

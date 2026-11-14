# frozen_string_literal: true

require_relative '../../lib/do/record'
require_relative 'issue_responses'

module Do
  module Testing
    # The calls `record` makes, expected on the fake runner: the recorded
    # #24 answer to the issue query, changed where a spec needs another
    # ledger, issue body or sub-issue, then REST reads and writes of the
    # issue body and the ledger comment, and the git calls for the base and
    # the gate file. Every write is synthesised; none was recorded.
    module RecordCalls
      include IssueResponses

      ISSUE_PATH = 'repos/sgbett/dotfiles-claude/issues/24'
      LEDGER_PATH = 'repos/sgbett/dotfiles-claude/issues/comments/6867069660'
      MARKER = "<!-- do:breakdown -->\n"

      # Runs record with +arguments+ on the fake runner, returning the exit
      # code and the output as parsed JSON.
      def record(*arguments)
        outcome = Do::Record.call(arguments, runner: fake_runner)
        [outcome.exit_code, JSON.parse(outcome.to_json)]
      end

      # The recorded answer with +ledger+ as the ledger's text after its
      # marker, and the block's changes.
      def record_response(ledger: "- [ ] **L1 One.**\n- [ ] **L2 Two.**\n")
        issue_response do |issue, data|
          issue['comments']['nodes'][0]['body'] = "#{MARKER}#{ledger}"
          yield issue, data if block_given?
        end
      end

      def ledger_text(response)
        ledger_body(response.dig('data', 'repository', 'issueOrPullRequest'))
      end

      def expect_base(base = 'master')
        fake_runner.expect_call(['git', 'check-ref-format', '--branch', base], stdout: "#{base}\n")
      end

      def expect_read(path, body)
        fake_runner.expect_call(['gh', 'api', '--hostname', 'github.com', '-X', 'GET', path],
                                stdout: JSON.generate('body' => body))
      end

      def expect_write(path, body)
        fake_runner.expect_call(['gh', 'api', '--hostname', 'github.com', '-X', 'PATCH', path, '--input', '-'],
                                stdin: JSON.generate('body' => body), stdout: JSON.generate('body' => body))
      end

      # The re-read before a write, the write, and the read back after it.
      def expect_edit(path, before, after, read_back: after)
        expect_read(path, before)
        expect_write(path, after)
        expect_read(path, read_back)
      end

      def expect_common_directory
        fake_runner.expect_call(%w[git rev-parse --path-format=absolute --git-common-dir],
                                stdout: "#{sandbox.work_directory}/.git\n")
      end

      def gate_path
        File.join(sandbox.work_directory, '.git', 'do', 'I_kwDOQzoXSs8AAAABfBUanQ-gate.md')
      end

      def write_gate_file(text)
        FileUtils.mkdir_p(File.dirname(gate_path))
        File.write(gate_path, text)
      end

      def gh_writes
        fake_runner.calls.map { |call| call[:argv] }.select { |argv| argv.include?('PATCH') }
      end

      # A sub-issue node of state +state+; +by+ as for issue_node.
      def sub_issue_node(number, repository = recorded_repository, state: 'OPEN', **options)
        issue_node(number, repository, **options).merge('state' => state)
      end
    end
  end
end

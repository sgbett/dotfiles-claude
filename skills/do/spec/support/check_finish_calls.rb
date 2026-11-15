# frozen_string_literal: true

require 'digest'
require_relative '../../lib/do/scripts_checkout'
require_relative 'check_responses'
require_relative 'copilot_signal_calls'

module Do
  module Testing
    # The calls of `preflight check`'s last steps, expected on the fake
    # runner: the scripts' own checkout, the security focus, the Copilot
    # signal and the working tree. See CheckCalls.
    module CheckFinishCalls
      include CheckResponses
      include CopilotSignalCalls

      SCRIPTS_DEFAULTS = { status: '', ruby_status: '', default: 'refs/remotes/origin/master', ancestor: true,
                           head: BASE_SHA, diff: '' }.freeze
      # The skill's directories.
      DIRECTORIES = %w[skills/do skills/_support].freeze
      # Every file mise reads for the Ruby the scripts run on, in each
      # directory from the top level to skills/_support/bin, where it starts.
      RUBY_FILES = ['', 'skills/', 'skills/_support/', 'skills/_support/bin/'].flat_map do |directory|
        %w[.ruby-version Gemfile .tool-versions mise.toml .mise.toml .miserc.toml .config/miserc.toml]
          .map { |name| "#{directory}#{name}" }
      end.freeze
      STATUS = %w[-c core.fsmonitor=false --no-optional-locks status --porcelain=v1 -z --untracked-files=all].freeze

      # +top+ nil means the scripts aren't in a git checkout. Otherwise
      # +checkout+ can give the porcelain +status+ for the skill's
      # directories and +ruby_status+ for the files that pick the Ruby,
      # origin's HEAD as +default+, whether HEAD is its +ancestor+, and the
      # +head+ and +diff+ an unreviewed checkout's digest is made from.
      def expect_scripts_step(top: nil, skill_directory: scripts_skill_directory, **checkout)
        fake_runner.expect_call(%w[git rev-parse --show-toplevel], stdout: "#{sandbox.work_directory}\n")
        fake_runner.expect_call(['git', '-C', skill_directory, 'rev-parse', '--show-toplevel'],
                                stdout: top ? "#{top}\n" : '', exit_status: top ? 0 : 128)
        expect_scripts_checkout(top, SCRIPTS_DEFAULTS.merge(checkout)) if top
      end

      # +claude_md+ is CLAUDE.md's text, nil for none; +rules+ maps each
      # file under .claude/rules/ to its text, nil for no such directory.
      def expect_focus_step(claude_md: "# Example\n\n## Code Style\n\nPlain.\n", rules: nil, ref: BASE_SHA,
                            repository: HERE)
        expect_contents('CLAUDE.md', ref, claude_md && contents_file('CLAUDE.md', claude_md), repository: repository)
        expect_contents('.claude/rules', ref, rules && rules.keys.map { |path| { 'path' => path, 'type' => 'file' } },
                        repository: repository)
        rules&.each { |path, text| expect_contents(path, ref, contents_file(path, text), repository: repository) }
      end

      # A contents API call answered with +body+, or with the recorded 404
      # for nil.
      def expect_contents(path, ref, body, repository: HERE)
        call = ['gh', 'api', '--hostname', 'github.com', '-X', 'GET', "repos/#{repository}/contents/#{path}", '-f',
                "ref=#{ref}"]
        return fake_runner.expect_call(call, stdout: JSON.generate(body)) if body

        fake_runner.expect_call(call, exit_status: 1, stdout: fixture('contents/rules-not-found.json'),
                                      stderr: fixture('contents/rules-not-found.stderr'))
      end

      # The base branch's rules, and the instructions at its commit; +signal+
      # as for CopilotSignalCalls#expect_copilot_signal.
      def expect_copilot_step(ref: BASE_SHA, repository: HERE, **signal)
        expect_copilot_signal(ref: ref, repository: repository, **signal)
      end

      def expect_changes_step(status: '')
        fake_runner.expect_call(%w[git -c core.fsmonitor=false --no-optional-locks status --porcelain=v1 -z
                                   --untracked-files=all], stdout: status)
      end

      # A directory to stand for the running skill's, with nothing in it.
      def scripts_skill_directory
        @scripts_skill_directory ||= sandbox.path('scripts', 'skills', 'do').tap { |path| FileUtils.mkdir_p(path) }
      end

      def scripts_top
        sandbox.path('scripts')
      end

      private

      def expect_scripts_checkout(top, checkout)
        expect_scripts_status(top, checkout)
        expect_line(['git', '-C', top, 'symbolic-ref', '--quiet', 'refs/remotes/origin/HEAD'], checkout[:default])
        if checkout[:default]
          fake_runner.expect_call(['git', '-C', top, 'merge-base', '--is-ancestor', 'HEAD', checkout[:default]],
                                  exit_status: checkout[:ancestor] ? 0 : 1)
        end
        reviewed = changes(checkout).empty? && checkout[:default] && checkout[:ancestor]
        expect_scripts_digest(top, checkout) unless reviewed
      end

      # The changes under the skill's directories, then to the files that
      # pick the Ruby, ignored ones included.
      def expect_scripts_status(top, checkout)
        fake_runner.expect_call(['git', '-C', top, *STATUS, '--', *DIRECTORIES], stdout: checkout[:status])
        fake_runner.expect_call(['git', '-C', top, *STATUS, '--ignored', '--', *RUBY_FILES],
                                stdout: checkout[:ruby_status])
      end

      def expect_scripts_digest(top, checkout)
        fake_runner.expect_call(['git', '-C', top, 'rev-parse', '--verify', 'HEAD'], stdout: "#{checkout[:head]}\n")
        fake_runner.expect_call(['git', '-C', top, '-c', 'core.fsmonitor=false', 'diff', '--binary', '--no-ext-diff',
                                 '--no-textconv', 'HEAD', '--', *DIRECTORIES, *RUBY_FILES], stdout: checkout[:diff])
        unversioned = unversioned(checkout)
        return if unversioned.empty?

        fake_runner.expect_call(['git', '-C', top, 'hash-object', '--no-filters', '--', *unversioned],
                                stdout: lines(unversioned.map { |path| Digest::SHA1.hexdigest(path) }))
      end

      # Both statuses' entries, once each, as a file that picks the Ruby can
      # be under the skill's directories too.
      def changes(checkout)
        Do::Porcelain.entries(checkout[:status] + checkout[:ruby_status]).uniq
      end

      # The untracked and ignored files whose contents the digest holds.
      def unversioned(checkout)
        changes(checkout).select { |change| change.untracked? || change.ignored? }.map(&:path)
      end
    end
  end
end

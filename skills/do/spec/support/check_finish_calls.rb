# frozen_string_literal: true

require 'digest'
require_relative '../../lib/do/scripts_checkout'
require_relative 'check_responses'

module Do
  module Testing
    # The calls of `preflight check`'s last steps, expected on the fake
    # runner: the scripts' own checkout, the security focus and the working
    # tree. See CheckCalls.
    module CheckFinishCalls
      include CheckResponses

      SCRIPTS_DEFAULTS = { status: '', default: 'refs/remotes/origin/master', ancestor: true, head: BASE_SHA,
                           diff: '' }.freeze
      # The skill's directories, then every file mise reads for the Ruby they run on.
      PATHSPECS = ['--', 'skills/do', 'skills/_support', '.ruby-version', 'mise.toml', '.mise.toml', '.tool-versions',
                   'mise.local.toml', '.config/mise.toml', '.mise/config.toml', 'skills/.ruby-version',
                   'skills/.tool-versions', 'skills/mise.toml'].freeze

      # +top+ nil means the scripts aren't in a git checkout. Otherwise
      # +checkout+ can give the porcelain +status+ for the skill's
      # directories, origin's HEAD as +default+, whether HEAD is its
      # +ancestor+, and the +head+ and +diff+ an unreviewed checkout's digest
      # is made from.
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
        fake_runner.expect_call(['git', '-C', top, '-c', 'core.fsmonitor=false', '--no-optional-locks', 'status',
                                 '--porcelain=v1', '-z', '--untracked-files=all', *PATHSPECS],
                                stdout: checkout[:status])
        expect_line(['git', '-C', top, 'symbolic-ref', '--quiet', 'refs/remotes/origin/HEAD'], checkout[:default])
        if checkout[:default]
          fake_runner.expect_call(['git', '-C', top, 'merge-base', '--is-ancestor', 'HEAD', checkout[:default]],
                                  exit_status: checkout[:ancestor] ? 0 : 1)
        end
        reviewed = checkout[:status].empty? && checkout[:default] && checkout[:ancestor]
        expect_scripts_digest(top, checkout) unless reviewed
      end

      def expect_scripts_digest(top, checkout)
        fake_runner.expect_call(['git', '-C', top, 'rev-parse', '--verify', 'HEAD'], stdout: "#{checkout[:head]}\n")
        fake_runner.expect_call(['git', '-C', top, '-c', 'core.fsmonitor=false', 'diff', '--binary', '--no-ext-diff',
                                 '--no-textconv', 'HEAD', *PATHSPECS], stdout: checkout[:diff])
        untracked = Do::Porcelain.entries(checkout[:status]).select(&:untracked?).map(&:path)
        return if untracked.empty?

        fake_runner.expect_call(['git', '-C', top, 'hash-object', '--no-filters', '--', *untracked],
                                stdout: lines(untracked.map { |path| Digest::SHA1.hexdigest(path) }))
      end
    end
  end
end

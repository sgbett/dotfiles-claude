# frozen_string_literal: true

require_relative '../../lib/do/git'
require_relative 'check_responses'

module Do
  module Testing
    # The calls of `preflight check`'s branch step, expected on the fake
    # runner: the push remote's branches, the local branch and the commits
    # the push remote lacks. See CheckCalls.
    module CheckBranchCalls
      include CheckResponses

      BRANCH_DEFAULTS = { branch: BRANCH, urls: [ORIGIN_URL], remote_tip: nil, remote_tips: nil, local_tip: nil,
                          other_branches: { 'refs/heads/master' => BASE_SHA }, other_tips_here: true, config: {},
                          base_here: true, lacking: [] }.freeze
      REMOTE_READ = ['git', *Do::Git::NO_HOOKS_OR_FSMONITOR].freeze

      # Tips are nil for no such branch: each push URL in +urls+ answers
      # +remote_tip+, or its own of +remote_tips+, beside +other_branches+,
      # full names to tips. +config+ holds branch.<name>.remote, pushRemote
      # and merge; +base_here+ whether the base commit is here, without a
      # fetch, and +other_tips_here+ whether the other branches' tips are,
      # rather than missing and failing to fetch, to list a branch the push
      # remote lacks against; +lacking+ is the log lines. The remote's tip is
      # already here (branch_facts_spec covers fetching it).
      def expect_branch_step(**overrides)
        branch = BRANCH_DEFAULTS.merge(overrides)
        ref = "refs/heads/#{branch[:branch]}"
        tips = expect_remote_tips(branch, ref)
        return if tips.uniq.length > 1

        remote_tip = tips.first
        expect_line(['git', 'rev-parse', '--verify', '--quiet', "#{remote_tip}^{commit}"], remote_tip) if remote_tip
        expect_line(['git', 'rev-parse', '--verify', '--quiet', ref], branch[:local_tip])
        expect_local_branch(branch, ref, remote_tip) if branch[:local_tip]
      end

      private

      # Each push URL's ls-remote, answered with its branches, sorted by name
      # as git lists them; returns the tips.
      def expect_remote_tips(branch, ref)
        tips = branch[:remote_tips] || branch[:urls].map { branch[:remote_tip] }
        branch[:urls].zip(tips).each do |url, tip|
          advertised = branch[:other_branches].merge(ref => tip).compact.sort
          fake_runner.expect_call([*REMOTE_READ, 'ls-remote', '--heads', url],
                                  stdout: lines(advertised.map { |name, sha| "#{sha}\t#{name}" }))
        end
        tips
      end

      def expect_local_branch(branch, ref, remote_tip)
        %w[remote pushRemote merge].each do |key|
          expect_line(['git', 'config', '--get', "branch.#{branch[:branch]}.#{key}"], branch[:config][key.to_sym])
        end
        return expect_log(branch, ["#{remote_tip}..#{ref}"]) if remote_tip

        expect_base(branch)
        measured = expect_other_tips(branch)
        expect_log(branch, ['--stdin', ref, '--not', BASE_SHA], stdin: lines(measured.map { |tip| "^#{tip}" }))
      end

      def expect_log(branch, revisions, stdin: nil)
        fake_runner.expect_call(['git', 'log', '--no-show-signature', '--format=%h %an %s', '--max-count=51',
                                 *revisions, '--'], stdin: stdin, stdout: lines(branch[:lacking]))
      end

      # The base commit GitHub gave, here or fetched through the first push
      # URL.
      def expect_base(branch)
        present = ['git', 'rev-parse', '--verify', '--quiet', "#{BASE_SHA}^{commit}"]
        return expect_line(present, BASE_SHA) if branch[:base_here]

        expect_line(present, nil)
        fake_runner.expect_call([*REMOTE_READ, 'fetch', '--no-tags', '--quiet', branch[:urls].first, BASE_SHA])
      end

      # The other branches' tips, here or missing and failing to fetch
      # through the first push URL; returns those log measures against.
      def expect_other_tips(branch)
        tips = branch[:other_branches].values.uniq
        return [] if tips.empty?

        here = branch[:other_tips_here]
        types = tips.map { |tip| here ? 'commit' : "#{tip} missing" }
        fake_runner.expect_call(['git', 'cat-file', '--batch-check=%(objecttype)'],
                                stdin: lines(tips), stdout: lines(types))
        return tips if here

        fake_runner.expect_call([*REMOTE_READ, 'fetch', '--no-tags', '--quiet', branch[:urls].first, *tips],
                                exit_status: 128, stderr: "fatal: remote error: upload-pack: not our ref\n")
        []
      end
    end
  end
end

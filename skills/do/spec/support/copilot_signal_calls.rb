# frozen_string_literal: true

require_relative '../../lib/do/copilot_signal'

module Do
  module Testing
    # The calls CopilotSignal makes, expected on the fake runner: the rules
    # for a branch, then .github/copilot-instructions.md at a ref. Unless a
    # spec says otherwise, they answer as this repository's master does: no
    # rules, as recorded, and no instructions, the recorded 404.
    module CopilotSignalCalls
      def expect_copilot_signal(repository: 'sgbett/dotfiles-claude', branch: 'master', ref: 'master',
                                rules: fixture('rest/branch-rules-none.json'), instructions: nil)
        expect_branch_rules(rules, repository: repository, branch: branch)
        expect_instructions(instructions, repository: repository, ref: ref)
      end

      # The rules call for +branch+, answered with +rules+: gh's output, or a
      # Hash of result fields.
      def expect_branch_rules(rules, repository:, branch:)
        fake_runner.expect_call(['gh', 'api', '--hostname', 'github.com', '-X', 'GET',
                                 "repos/#{repository}/rules/branches/#{SkillSupport::Gh.path_segment(branch)}",
                                 '-f', 'per_page=100'], **(rules.is_a?(Hash) ? rules : { stdout: rules }))
      end

      # The contents call for the instructions at +ref+, answered with a file
      # holding +answer+, a String; a directory's listing, an Array; or, for
      # nil, the recorded 404.
      def expect_instructions(answer, repository:, ref:)
        call = ['gh', 'api', '--hostname', 'github.com', '-X', 'GET',
                "repos/#{repository}/contents/#{Do::CopilotSignal::INSTRUCTIONS}", '-f', "ref=#{ref}"]
        return fake_runner.expect_call(call, stdout: JSON.generate(instructions_body(answer))) if answer

        fake_runner.expect_call(call, exit_status: 1, stdout: fixture('contents/rules-not-found.json'),
                                      stderr: fixture('contents/rules-not-found.stderr'))
      end

      private

      def instructions_body(answer)
        return answer if answer.is_a?(Array)

        { 'name' => File.basename(Do::CopilotSignal::INSTRUCTIONS), 'path' => Do::CopilotSignal::INSTRUCTIONS,
          'type' => 'file', 'encoding' => 'base64', 'content' => [answer].pack('m') }
      end
    end
  end
end

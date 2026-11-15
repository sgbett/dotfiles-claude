# frozen_string_literal: true

module CopilotCheck
  module Testing
    # What setup reads from the base branch through the contents API, the
    # rubric and the security focus, as a unit spec's fake runner answers
    # it. ScriptCalls includes it.
    module ContentsCalls
      # The rubric read: +text+ the file's, or nil for GitHub's recorded 404.
      def expect_rubric(text = nil)
        expect_contents('.github/copilot-instructions.md', text)
      end

      # The security focus's reads on the base branch: CLAUDE.md, holding
      # +claude_md+ or absent for nil, and no .claude/rules/.
      def expect_focus(claude_md = nil)
        expect_contents('CLAUDE.md', claude_md)
        expect_contents('.claude/rules', nil)
      end

      # The read of +path+ on the base branch: a file holding +text+, or
      # GitHub's recorded 404 for nil.
      def expect_contents(path, text)
        return fake_runner.expect_call(contents_call(path), stdout: as_json(rubric_response(text, path: path))) if text

        fake_runner.expect_call(contents_call(path), exit_status: 1, stdout: fixture('contents/rubric-not-found.json'),
                                                     stderr: fixture('contents/rubric-not-found.stderr'))
      end

      def contents_call(path)
        ['gh', 'api', '--hostname', 'github.com', '-X', 'GET', "repos/#{GateCalls::HERE}/contents/#{path}", '-f',
         'ref=master']
      end

      # The contents API's answer for a file holding +text+, the rubric
      # unless +path+ names another.
      def rubric_response(text, path: '.github/copilot-instructions.md')
        { 'type' => 'file', 'encoding' => 'base64', 'content' => [text].pack('m'), 'path' => path }
      end
    end
  end
end

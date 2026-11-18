# frozen_string_literal: true

require_relative 'script_runs'
require_relative '../../lib/repo_consistency/vendored_paths'

module RepoConsistency
  module Testing
    # The calls git-settings audit makes and their answers: every argument
    # of each gh call, as the fake runner and the gh shim match them,
    # answered as recorded for sgbett/bsv-ruby-sdk or as a synthesised
    # repository's answers (RepositoryAnswers) say.
    module ScriptCalls
      include ScriptRuns

      HOST = 'github.com'
      RECORDED = 'sgbett/bsv-ruby-sdk'
      RECORDED_RULESETS = [15_226_411, 14_583_984].freeze
      FIXTURES = File.expand_path('../fixtures', __dir__)
      LOGIN = ['gh', 'auth', 'status', '--active', '--hostname', HOST].freeze
      PER_PAGE = 'per_page=100'
      # GitHub's 403 on a private repository whose plan lacks rulesets and
      # branch protection, synthesised: no public repository can give it.
      PLAN_MESSAGE = 'Upgrade to GitHub Pro or make this repository public to enable this feature.'
      # A CLAUDE.md without a tier line, standing for sgbett/bsv-ruby-sdk's
      # (spec/fixtures/README.md says why that one isn't recorded).
      UNDECLARED_CLAUDE_MD = "# bsv-ruby-sdk\n\nRuby SDK. No tier line yet.\n"

      def api_call(path, *fields, host: HOST)
        ['gh', 'api', '--hostname', host, '-X', 'GET', path, *fields.flat_map { |field| ['-f', field] }]
      end

      def repository_call(repository)
        api_call("repos/#{repository}")
      end

      def rules_call(repository, branch)
        api_call("repos/#{repository}/rules/branches/#{branch}", PER_PAGE)
      end

      def rulesets_call(repository)
        api_call("repos/#{repository}/rulesets", PER_PAGE)
      end

      def ruleset_call(repository, id)
        api_call("repos/#{repository}/rulesets/#{id}")
      end

      def protection_call(repository, branch)
        api_call("repos/#{repository}/branches/#{branch}/protection")
      end

      def contents_call(repository, path, branch)
        api_call("repos/#{repository}/contents/#{path}", "ref=#{branch}")
      end

      # A gh shim entry: +call+ with its "gh" dropped, answered as +answer+
      # says (stdout or stdout_file, stderr, exit).
      def entry(call, **answer)
        { args: call.drop(1), **answer }
      end

      def recorded(name)
        File.join(FIXTURES, name)
      end

      def login_entry(logged_in: true)
        stderr = logged_in ? '' : "You are not logged into any accounts on #{HOST}\n"
        entry(LOGIN, exit: logged_in ? 0 : 1, stderr: stderr)
      end

      # The contents API's answer for a file holding +text+ at +path+.
      def file_response(path, text)
        { 'name' => File.basename(path), 'path' => path, 'type' => 'file', 'encoding' => 'base64',
          'content' => [text].pack('m') }
      end

      # GitHub's recorded 404 for a path the default branch lacks.
      def not_found_answer
        { exit: 1, stdout_file: recorded('contents/not-found.json'),
          stderr: File.read(recorded('contents/not-found.stderr')) }
      end

      # GitHub's recorded 404 for a default branch without classic protection.
      def not_protected_answer
        { exit: 1, stdout_file: recorded('protection/bsv-ruby-sdk-master.json'),
          stderr: File.read(recorded('protection/bsv-ruby-sdk-master.stderr')) }
      end

      def plan_forbidden_answer
        body = { 'message' => PLAN_MESSAGE, 'documentation_url' => 'https://docs.github.com/rest', 'status' => '403' }
        { exit: 1, stdout: JSON.generate(body), stderr: "gh: #{PLAN_MESSAGE} (HTTP 403)\n" }
      end

      # GitHub's answer for a repository gh can't read, +status+ 404 as for
      # one that doesn't exist or isn't visible, or 403, as for one the
      # token's scopes don't reach, shaped as the recorded 404s are.
      def unreadable_answer(status, message)
        { exit: 1, stdout: JSON.generate('message' => message, 'documentation_url' => 'https://docs.github.com/rest',
                                         'status' => status.to_s),
          stderr: "gh: #{message} (HTTP #{status})\n" }
      end

      # sgbett/bsv-ruby-sdk's answers as recorded, in the order the reader
      # calls, apart from CLAUDE.md, which holds +claude_md+.
      def recorded_entries(claude_md: UNDECLARED_CLAUDE_MD)
        [entry(repository_call(RECORDED), stdout_file: recorded('repos/bsv-ruby-sdk.json')),
         entry(rules_call(RECORDED, 'master'), stdout_file: recorded('rules/bsv-ruby-sdk-master.json')),
         entry(rulesets_call(RECORDED), stdout_file: recorded('rulesets/bsv-ruby-sdk.json')),
         *recorded_ruleset_entries,
         entry(protection_call(RECORDED, 'master'), **not_protected_answer),
         *file_entries(RECORDED, 'master', VendoredPaths::CLAUDE_MD => claude_md)]
      end

      def recorded_ruleset_entries
        RECORDED_RULESETS.map do |id|
          entry(ruleset_call(RECORDED, id), stdout_file: recorded("rulesets/bsv-ruby-sdk-#{id}.json"))
        end
      end

      # The five file reads of +repository+ at +branch+, each answered with
      # its text in +files+ or GitHub's recorded 404.
      def file_entries(repository, branch, files)
        VendoredPaths::ALL.map do |path|
          answer = files[path] ? { stdout: JSON.generate(file_response(path, files[path])) } : not_found_answer
          entry(contents_call(repository, path, branch), **answer)
        end
      end

      # What the recorded sgbett/bsv-ruby-sdk differs from the template in,
      # as the audit lists it.
      def recorded_drift
        ['rule missing: deletion', 'rule missing: non_fast_forward', 'rule missing: pull_request',
         'ruleset "Git workflow" missing', 'ruleset "Block unless CI green" grants a bypass',
         'ruleset "Copilot review for default branch" grants a bypass', 'allow_squash_merge on',
         'allow_rebase_merge on', 'tier line undeclared', 'vendored rules file missing',
         'vendored hook missing: push-guard', 'vendored hook missing: push-guard.rb',
         'hooks entry missing from .claude/settings.json']
      end

      # Feeds +entries+ to the fake runner, in order.
      def expect_entries(entries)
        entries.each do |answer|
          stdout = answer.key?(:stdout_file) ? File.read(answer[:stdout_file]) : answer.fetch(:stdout, '')
          fake_runner.expect_call(['gh', *answer[:args]], stdout: stdout, stderr: answer.fetch(:stderr, ''),
                                                          exit_status: answer.fetch(:exit, 0))
        end
      end
    end
  end
end

# frozen_string_literal: true

require_relative 'script_calls'
require_relative '../../lib/repo_consistency/vendored_paths'

module RepoConsistency
  module Testing
    # sgbett/bsv-ruby-sdk as recorded (spec/fixtures/README.md): its
    # answers to each read the audit makes, in order, and the drift the
    # audit finds in them.
    module RecordedRun
      include ScriptCalls

      RECORDED = 'sgbett/bsv-ruby-sdk'
      RECORDED_RULESETS = [15_226_411, 14_583_984].freeze
      # The .claude directory's tree, as the recorded root tree lists it.
      RECORDED_CLAUDE_TREE = 'eecdcc7a616b52dd805c6b3cda68eeb89907ccd6'
      # A CLAUDE.md without a tier line, standing for sgbett/bsv-ruby-sdk's
      # (spec/fixtures/README.md says why that one isn't recorded).
      UNDECLARED_CLAUDE_MD = "# bsv-ruby-sdk\n\nRuby SDK. No tier line yet.\n"

      # The answers in the order the reader calls, apart from CLAUDE.md,
      # which holds +claude_md+.
      def recorded_entries(claude_md: UNDECLARED_CLAUDE_MD)
        [entry(repository_call(RECORDED), stdout_file: recorded('repos/bsv-ruby-sdk.json')),
         entry(rules_call(RECORDED, 'master'), stdout_file: recorded('rules/bsv-ruby-sdk-master.json')),
         entry(rulesets_call(RECORDED), stdout_file: recorded('rulesets/bsv-ruby-sdk.json')),
         *recorded_ruleset_entries,
         entry(protection_call(RECORDED, 'master'), **not_protected_answer),
         *file_entries(RECORDED, 'master', VendoredPaths::CLAUDE_MD => claude_md),
         *recorded_tree_entries]
      end

      def recorded_ruleset_entries
        RECORDED_RULESETS.map do |id|
          entry(ruleset_call(RECORDED, id), stdout_file: recorded("rulesets/bsv-ruby-sdk-#{id}.json"))
        end
      end

      # Its trees list no instruction file but CLAUDE.md, so .claude's tree
      # is the last read.
      def recorded_tree_entries
        [entry(tree_call(RECORDED, 'master'), stdout_file: recorded('trees/bsv-ruby-sdk-master.json')),
         entry(subtree_call(RECORDED, RECORDED_CLAUDE_TREE), stdout_file: recorded('trees/bsv-ruby-sdk-claude.json'))]
      end

      # What it differs from the template in, as the audit lists it.
      def recorded_drift
        ['rule missing: deletion', 'rule missing: non_fast_forward', 'rule missing: pull_request',
         'ruleset "Git workflow" missing', 'ruleset "Block unless CI green" grants a bypass',
         'ruleset "Copilot review for default branch" grants a bypass', 'allow_squash_merge on',
         'allow_rebase_merge on', 'tier line undeclared', 'vendored rules file missing',
         'vendored hook missing: push-guard', 'vendored hook missing: push-guard.rb',
         'hooks entry missing from .claude/settings.json']
      end
    end
  end
end

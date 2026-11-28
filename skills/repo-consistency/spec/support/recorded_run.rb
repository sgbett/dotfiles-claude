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
      SYNTHESISED_CLAUDE_MD = "# bsv-ruby-sdk\n\nRuby SDK. No tier line.\n"
      # A vendored rules file the repository doesn't carry, so that the run
      # exercises the protected checks; its body matches no profile.
      SYNTHESISED_RULES_FILE = "<!-- vendored from sgbett/dotfiles-claude profiles/git-workflow.md -->\n\n" \
                               "# Git workflow\n\nA stand-in for a vendored copy.\n"

      # The answers in the order the reader calls.
      def recorded_entries
        [entry(repository_call(RECORDED), stdout_file: recorded('repos/bsv-ruby-sdk.json')),
         entry(rules_call(RECORDED, 'master'), stdout_file: recorded('rules/bsv-ruby-sdk-master.json')),
         entry(rulesets_call(RECORDED), stdout_file: recorded('rulesets/bsv-ruby-sdk.json')),
         *recorded_ruleset_entries,
         entry(protection_call(RECORDED, 'master'), **not_protected_answer),
         *file_entries(RECORDED, 'master', VendoredPaths::CLAUDE_MD => SYNTHESISED_CLAUDE_MD,
                                           VendoredPaths::RULES_FILE => SYNTHESISED_RULES_FILE),
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
         'ruleset "Git workflow" missing', 'ruleset "Project and release branches" missing', 'ruleset "Tags" missing',
         'ruleset "Block unless CI green" grants a bypass',
         'ruleset "Copilot review for default branch" grants a bypass', 'allow_squash_merge on',
         'allow_rebase_merge on', 'vendored rules file differs from the profile']
      end
    end
  end
end

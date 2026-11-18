# frozen_string_literal: true

require_relative 'script_calls'
require_relative 'template_fixture'

module RepoConsistency
  module Testing
    # The answers one repository gives the audit's reads, synthesised from
    # the recorded shapes of sgbett/bsv-ruby-sdk: built compliant with the
    # template fixture, then changed by a spec for its case. #entries gives
    # the gh shim's entries in the order RepositoryReader calls, which
    # expect_entries feeds the fake runner too.
    class RepositoryAnswers
      include ScriptCalls

      attr_reader :repository
      attr_accessor :branch, :flags, :rules, :rulesets, :protection, :files, :plan_forbids

      def initialize(repository, branch: 'master')
        @repository = repository
        @branch = branch
        @flags = TemplateFixture::REPOSITORY.dup
        @rules = TemplateFixture::RULESET['rules'].map(&:dup)
        @rulesets = [{ 'id' => 1, 'name' => TemplateFixture::RULESET['name'], 'bypass_actors' => [] }]
        @protection = nil
        @plan_forbids = false
        @files = compliant_files
      end

      def compliant_files
        { VendoredPaths::CLAUDE_MD => "# Project\n\nGit tier: collaborative\n",
          VendoredPaths::RULES_FILE => TemplateFixture::HEADER + TemplateFixture::PROFILE,
          VendoredPaths::HOOK_FILES[0] => TemplateFixture::HOOKS['push-guard'],
          VendoredPaths::HOOK_FILES[1] => TemplateFixture::HOOKS['push-guard.rb'],
          VendoredPaths::SETTINGS_FILE => JSON.generate(TemplateFixture::HOOKS_SETTINGS) }
      end

      def entries
        [entry(repository_call(repository), stdout: JSON.generate(repository_response)), *rule_entries,
         protection_entry, *file_entries(repository, branch, files)]
      end

      # The fields the reader takes of repos/{owner}/{repo}.
      def repository_response
        { 'full_name' => repository, 'default_branch' => branch, 'visibility' => 'private' }.merge(flags)
      end

      # The rules in force, the ruleset list, which carries no bypass
      # actors, then each ruleset's detail, which does; or, where the plan
      # forbids rulesets, the 403 for the first two and no detail.
      def rule_entries
        rules_read = rules_call(repository, branch)
        rulesets_read = rulesets_call(repository)
        if plan_forbids
          [rules_read, rulesets_read].map { |call| entry(call, **plan_forbidden_answer) }
        else
          [entry(rules_read, stdout: JSON.generate(rules)), entry(rulesets_read, stdout: JSON.generate(ruleset_list)),
           *ruleset_detail_entries]
        end
      end

      def ruleset_list
        rulesets.map { |ruleset| ruleset.slice('id', 'name') }
      end

      def ruleset_detail_entries
        rulesets.map { |ruleset| entry(ruleset_call(repository, ruleset['id']), stdout: JSON.generate(ruleset)) }
      end

      def protection_entry
        answer = if plan_forbids then plan_forbidden_answer
                 elsif protection.nil? then not_protected_answer
                 else { stdout: JSON.generate(protection) }
                 end
        entry(protection_call(repository, branch), **answer)
      end
    end
  end
end

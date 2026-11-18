# frozen_string_literal: true

require_relative 'hooks_entry'
require_relative 'template'
require_relative 'tier_line'
require_relative 'vendored_paths'

module RepoConsistency
  # The lines of drift between the template's projection and a
  # repository's, in a fixed order, each a fixed string or one built from a
  # validated identifier or a field name. A personal repository is held
  # only to its declaration; an undeclared one is reported against the
  # template, since that is then the expectation.
  module Drift
    LINEAR_HISTORY = 'required_linear_history'
    PLAN = 'rulesets unavailable on this plan'
    EXTRA_APPROVAL = 'pull_request requires extra approval for unattributed changes'
    PERSONAL_WITH_RULES = "tier line says personal but the default branch has #{Template::PULL_REQUEST} rules".freeze
    # A ruleset's name is GitHub's text, so only a plain one reaches a line;
    # any other ruleset is named by its id.
    PLAIN_NAME = /\A[A-Za-z0-9][A-Za-z0-9 ._-]{0,99}\z/

    module_function

    def lines(expected, actual)
      actual.tier == TierLine::PERSONAL ? personal_lines(actual) : collaborative_lines(expected, actual)
    end

    def personal_lines(actual)
      actual.rule_types.include?(Template::PULL_REQUEST) ? [PERSONAL_WITH_RULES] : []
    end

    def collaborative_lines(expected, actual)
      [plan_line(actual), rule_lines(expected, actual), pull_request_lines(expected, actual),
       linear_history_line(actual), ruleset_lines(expected, actual), flag_lines(expected, actual),
       protection_line(actual), branch_line(expected, actual), tier_line(actual),
       rules_file_lines(expected, actual), hook_lines(expected, actual), settings_line(actual)].flatten.compact
    end

    def plan_line(actual)
      PLAN unless actual.rulesets_available
    end

    def rule_lines(expected, actual)
      (expected.rule_types - actual.rule_types).map { |type| "rule missing: #{type}" }
    end

    def pull_request_lines(expected, actual)
      return if actual.merge_methods.nil?

      lines = (actual.merge_methods - expected.merge_methods).sort.map { |method| "pull_request allows #{method}" }
      lines << "pull_request requires #{actual.approvals} approvals" unless actual.approvals == expected.approvals
      lines << EXTRA_APPROVAL if actual.extra_approval == true && expected.extra_approval == false
      lines
    end

    def linear_history_line(actual)
      "rule present: #{LINEAR_HISTORY}" if actual.rule_types.include?(LINEAR_HISTORY)
    end

    def ruleset_lines(expected, actual)
      missing = (expected.ruleset_names - actual.ruleset_names).map { |name| "ruleset \"#{name}\" missing" }
      missing + actual.bypassing_rulesets.map { |id, name| "ruleset #{label(id, name)} grants a bypass" }
    end

    def label(id, name)
      PLAIN_NAME.match?(name.to_s) ? "\"#{name}\"" : id.to_s
    end

    def flag_lines(expected, actual)
      expected.flags.filter_map { |flag, value| "#{flag} #{value ? 'off' : 'on'}" unless actual.flags[flag] == value }
    end

    def protection_line(actual)
      additions = actual.protection_additions
      return if additions.nil?

      return 'classic protection present, redundant' if additions.empty?

      "classic protection present, adds: #{additions.join(', ')}"
    end

    def branch_line(expected, actual)
      "default branch is #{actual.default_branch}" unless actual.default_branch == expected.default_branch
    end

    def tier_line(actual)
      'tier line undeclared' if actual.tier == TierLine::UNDECLARED
    end

    def rules_file_lines(expected, actual)
      if actual.rules_body.nil?
        'vendored rules file missing'
      else
        [('vendored rules file differs from the profile' unless actual.rules_body == expected.rules_body),
         ('vendored rules header is not the convention' unless actual.rules_header_ok)]
      end
    end

    def hook_lines(expected, actual)
      expected.hooks.filter_map do |name, text|
        if actual.hooks[name].nil? then "vendored hook missing: #{name}"
        elsif actual.hooks[name] != text then "vendored hook differs: #{name}"
        end
      end
    end

    def settings_line(actual)
      case actual.hooks_entry
      when HooksEntry::MISSING, HooksEntry::ABSENT then "hooks entry missing from #{VendoredPaths::SETTINGS_FILE}"
      when HooksEntry::UNREADABLE then 'settings.json unreadable'
      end
    end

    private_class_method :personal_lines, :collaborative_lines, :plan_line, :rule_lines, :pull_request_lines,
                         :linear_history_line, :ruleset_lines, :label, :flag_lines, :protection_line, :branch_line,
                         :tier_line, :rules_file_lines, :hook_lines, :settings_line
  end
end

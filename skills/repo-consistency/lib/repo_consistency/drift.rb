# frozen_string_literal: true

require_relative 'template'
require_relative 'tier'

module RepoConsistency
  # The lines of drift between the template's projection and a
  # repository's, in a fixed order, each a fixed string or one built from a
  # validated identifier, a template's ruleset name, a field name, a tier
  # word or one of UserSkills' names, so no path or file text reaches one.
  # A personal repository is held only to its tier line and to having no
  # pull_request rule; a protected one to the whole template.
  module Drift
    LINEAR_HISTORY = 'required_linear_history'
    PLAN = 'rulesets unavailable on this plan'
    EXTRA_APPROVAL = 'pull_request requires extra approval for unattributed changes'
    # A line names a RulesetShape field as GitHub's ref_name key does.
    RULESET_FIELD_NAMES = { includes: 'include', excludes: 'exclude' }.freeze
    BYPASS = { granted: 'grants a bypass', unreadable: 'bypass actors unreadable' }.freeze
    PERSONAL_WITH_PULL_REQUESTS = 'no vendored rules file but the default branch requires pull requests'
    REDUNDANT_TIER_LINE = 'tier line states no difference, redundant'
    # A ruleset's name is GitHub's text, so only a plain one reaches a line;
    # any other ruleset is named by its id.
    PLAIN_NAME = /\A[A-Za-z0-9][A-Za-z0-9 ._-]{0,99}\z/
    UNSHIPPED_SKILL = "names a skill it doesn't ship:"
    SKILLS_UNCHECKED = { truncated: 'skill names unchecked: tree truncated',
                         linked: 'skill names unchecked: symlink or submodule',
                         unreadable: 'skill names unchecked: file too large or not a file',
                         too_many: 'skill names unchecked: too many instruction files' }.freeze

    module_function

    def lines(expected, actual)
      actual.tier == Tier::PERSONAL ? personal_lines(actual) : protected_lines(expected, actual)
    end

    def personal_lines(actual)
      [(PERSONAL_WITH_PULL_REQUESTS if actual.rule_types.include?(Template::PULL_REQUEST)), tier_line(actual)].compact
    end

    def protected_lines(expected, actual)
      [plan_line(actual), rule_lines(expected, actual), pull_request_findings(expected, actual).values,
       linear_history_line(actual), ruleset_lines(expected, actual), flag_lines(expected, actual),
       protection_line(actual), branch_line(expected, actual), tier_line(actual),
       rules_file_lines(expected, actual), skill_lines(actual)].flatten.compact
    end

    def plan_line(actual)
      PLAN unless actual.rulesets_available
    end

    def rule_lines(expected, actual)
      (expected.rule_types - actual.rule_types).map { |type| "rule missing: #{type}" }
    end

    # The lines on the first pull_request rule in force, by the parameter
    # each reports.
    def pull_request_findings(expected, actual)
      return {} if actual.merge_methods.nil?

      { Template::MERGE_METHODS => merge_method_lines(expected, actual),
        Template::APPROVALS => approval_lines(expected, actual),
        Template::EXTRA_APPROVAL => extra_approval_lines(expected, actual) }.reject { |_, lines| lines.empty? }
    end

    def merge_method_lines(expected, actual)
      (actual.merge_methods - expected.merge_methods).sort.map { |method| "pull_request allows #{method}" }
    end

    def approval_lines(expected, actual)
      actual.approvals == expected.approvals ? [] : ["pull_request requires #{actual.approvals} approvals"]
    end

    def extra_approval_lines(expected, actual)
      actual.extra_approval == true && expected.extra_approval == false ? [EXTRA_APPROVAL] : []
    end

    def linear_history_line(actual)
      "rule present: #{LINEAR_HISTORY}" if actual.rule_types.include?(LINEAR_HISTORY)
    end

    # Without rulesets on the plan, PLAN is the one cause of every ruleset
    # being absent, so it stands alone.
    def ruleset_lines(expected, actual)
      return [] unless actual.rulesets_available

      reported = { types: rule_types_reported(expected, actual),
                   parameters: pull_request_findings(expected, actual).keys }
      expected.rulesets.filter_map do |name, shape|
        template_ruleset_line(name, shape, actual.rulesets[name], reported)
      end + actual.ruleset_bypasses.map { |id, name, bypass| "ruleset #{label(id, name)} #{BYPASS.fetch(bypass)}" }
    end

    # The rule types whose difference on the default branch rule_lines and
    # linear_history_line already report.
    def rule_types_reported(expected, actual)
      (expected.rule_types - actual.rule_types) + ([LINEAR_HISTORY] & actual.rule_types)
    end

    def template_ruleset_line(name, shape, actual_shape, reported)
      return "ruleset \"#{name}\" missing" if actual_shape.nil?

      differences = shape.differences(actual_shape, **reported)
                         .map { |field| RULESET_FIELD_NAMES.fetch(field, field.to_s) }
      "ruleset \"#{name}\" differs: #{differences.join(', ')}" unless differences.empty?
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

    # A tier line earns its place only by stating a difference, and its word
    # must be the tier the rules file decides; collaborative, the retired
    # name, never is.
    def tier_line(actual)
      word = actual.tier_word
      return if word.nil?
      return "tier line says #{word} but the repository is #{actual.tier}" unless word == actual.tier

      REDUNDANT_TIER_LINE if actual.difference.nil?
    end

    # Only a protected repository is held to these, and the rules file is
    # what makes it one, so the file is never missing here.
    def rules_file_lines(expected, actual)
      [('vendored rules file differs from the profile' unless actual.rules_body == expected.rules_body),
       ('vendored rules header is not the convention' unless actual.rules_header_ok)]
    end

    def skill_lines(actual)
      return SKILLS_UNCHECKED.fetch(actual.skills_unchecked) if actual.skills_unchecked

      actual.unshipped_skills.map { |name| "#{UNSHIPPED_SKILL} #{name}" }
    end

    private_class_method :personal_lines, :protected_lines, :plan_line, :rule_lines, :pull_request_findings,
                         :merge_method_lines, :approval_lines, :extra_approval_lines, :linear_history_line,
                         :ruleset_lines, :rule_types_reported, :template_ruleset_line, :label, :flag_lines,
                         :protection_line, :branch_line, :tier_line, :rules_file_lines, :skill_lines
  end
end

# frozen_string_literal: true

module RepoConsistency
  # A ruleset reduced to what the audit compares with a template's: its
  # target, its enforcement, its ref_name patterns in either order, and its
  # rules' parameters by rule type. Built alike from a template file and
  # from GitHub's detail, whose shape is checked here rather than trusted;
  # anything malformed reads as empty, so it differs rather than fails.
  RulesetShape = Struct.new(:target, :enforcement, :includes, :excludes, :rules, keyword_init: true) do
    def self.of(ruleset)
      ref_name = hash_at(ruleset, 'conditions', 'ref_name')
      new(target: ruleset['target'], enforcement: ruleset['enforcement'], includes: patterns(ref_name['include']),
          excludes: patterns(ref_name['exclude']), rules: rules(ruleset['rules']))
    end

    def self.hash_at(value, *keys)
      found = keys.inject(value) { |within, key| within.is_a?(Hash) ? within[key] : nil }
      found.is_a?(Hash) ? found : {}
    end

    def self.patterns(value)
      value.is_a?(Array) ? value.map(&:to_s).sort : []
    end

    def self.rules(value)
      return {} unless value.is_a?(Array)

      value.grep(Hash).to_h { |rule| [rule['type'].to_s, hash_at(rule, 'parameters')] }
    end

    private_class_method :hash_at, :patterns, :rules

    # The fields, as members in order, in which +actual+ differs from this,
    # the template's shape. Rules differ when their types do, or when a rule
    # lacks a parameter value the template states; parameters the template
    # leaves unsaid are GitHub's defaults (it adds required_reviewers: [] to
    # pull_request), so they aren't compared. On a shape left to the rules
    # in force, the rule +types+ and +parameters+ whose difference a line on
    # those rules already reports aren't compared either.
    def differences(actual, types: [], parameters: [])
      skipped = @left_to_rules_in_force ? { types: types, parameters: parameters } : { types: [], parameters: [] }
      members.reject { |field| matches?(field, actual, **skipped) }
    end

    # Marks this the default branch's ruleset, whose rules in force are
    # checked too.
    def leave_to_rules_in_force
      @left_to_rules_in_force = true
    end

    private

    def matches?(field, actual, types:, parameters:)
      return self[field] == actual[field] unless field == :rules

      rules_match?(actual.rules, types, parameters)
    end

    # Equal compared types leave every unskipped template type in
    # +actual_rules+, so its parameters can be read there.
    def rules_match?(actual_rules, types, parameters)
      (rules.keys - types).sort == (actual_rules.keys - types).sort &&
        rules.all? do |type, stated|
          types.include?(type) || stated.except(*parameters).all? { |key, value| actual_rules[type][key] == value }
        end
    end
  end
end

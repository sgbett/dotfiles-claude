# frozen_string_literal: true

require_relative 'projection'
require_relative 'ruleset_shape'
require_relative 'skill_mentions'
require_relative 'template'
require_relative 'tier'
require_relative 'tier_line'
require_relative 'vendored_paths'

module RepoConsistency
  # A live repository's answers (RepositoryState) mapped to the fields the
  # audit compares (Projection). Only a validated value reaches a field a
  # drift line is built from: a merge method and an approval count are
  # checked here, and a ruleset's name is left for Drift to judge.
  class RepositoryProjection
    MERGE_METHOD = /\A[a-z_]+\z/
    ALL_MERGE_METHODS = %w[merge squash rebase].freeze
    HEADER_MARK = 'vendored from sgbett/dotfiles-claude'
    HEADER_LINES = 2
    BYPASS_ACTORS = 'bypass_actors'
    REVIEWS = 'required_pull_request_reviews'
    # What a classic protection can carry that the template lacks.
    PROTECTION_ADDITIONS = [REVIEWS, 'required_status_checks', 'restrictions'].freeze

    def self.call(state)
      new(state).call
    end

    def initialize(state)
      @state = state
    end

    def call
      Projection.new(**repository_fields, **rule_fields, **ruleset_fields, **file_fields, **skill_fields)
    end

    private

    def repository_fields
      declaration = TierLine.read(@state.files[VendoredPaths::CLAUDE_MD])
      { default_branch: @state.default_branch, tier: Tier.of(@state.files), tier_word: declaration.word,
        difference: declaration.difference, flags: @state.flags, protection_additions: protection_additions,
        pull_requests_required: pull_requests_required? }
    end

    def rule_fields
      { rulesets_available: @state.rulesets_available, rule_types: @state.rules.map { |rule| rule['type'] },
        **first_pull_request_fields }
    end

    # Only the first rule's values are compared, but every one is checked,
    # so a malformed rule can't read clean behind a sound one before it.
    def first_pull_request_fields
      pull_request_rules.map { |rule| pull_request_fields(rule) }.first ||
        { merge_methods: nil, approvals: nil, extra_approval: nil }
    end

    # A personal repository is held only to having no pull_request rule, so
    # its parameters go unread.
    def pull_request_rules
      return [] if Tier.of(@state.files) == Tier::PERSONAL

      @state.rules.select { |rule| rule['type'] == Template::PULL_REQUEST }
    end

    # A rule without parameters would leave every one unchecked, so it fails
    # rather than reading clean.
    def pull_request_fields(rule)
      parameters = rule['parameters']
      raise SkillSupport::UnexpectedResponse, 'a pull_request rule carries no parameters' unless parameters.is_a?(Hash)

      { merge_methods: merge_methods!(parameters[Template::MERGE_METHODS]),
        approvals: approvals!(parameters[Template::APPROVALS]),
        extra_approval: parameters[Template::EXTRA_APPROVAL] }
    end

    # Integer() would round 0.9 down to a template's 0 and read clean.
    def approvals!(count)
      return count if count.is_a?(Integer)

      raise SkillSupport::UnexpectedResponse, 'an approval count is not a whole number'
    end

    # The list is optional in GitHub's schema, and absent before GHES 3.17,
    # so its absence is read as the worst case rather than as none.
    def merge_methods!(methods)
      methods = ALL_MERGE_METHODS if methods.nil?
      raise SkillSupport::UnexpectedResponse, 'merge methods are not a list' unless methods.is_a?(Array)

      methods.each do |method|
        next if MERGE_METHOD.match?(method.to_s)

        raise SkillSupport::UnexpectedResponse, 'a merge method is not a plain name'
      end
    end

    def ruleset_fields
      by_name = @state.rulesets.group_by { |ruleset| ruleset['name'] }
      { rulesets: by_name.transform_values { |named| RulesetShape.of(named.first) },
        ruleset_bypasses: @state.rulesets.filter_map { |ruleset| bypass_entry(ruleset) } }
    end

    # A ruleset's bypass, by id and name: granted when its detail lists
    # actors, unreadable when the detail leaves the key out, as GitHub does
    # for a caller without admin rights, so that the audit never reports
    # clean where it cannot see; nothing for an empty list.
    def bypass_entry(ruleset)
      bypass = if !ruleset.key?(BYPASS_ACTORS) then :unreadable
               elsif !Array(ruleset[BYPASS_ACTORS]).empty? then :granted
               end
      [Integer(ruleset['id']), ruleset['name'], bypass] if bypass
    end

    # At any approval count, which protection_additions leaves out.
    def pull_requests_required?
      @state.rules.any? { |rule| rule['type'] == Template::PULL_REQUEST } ||
        (!@state.protection.nil? && !@state.protection[REVIEWS].nil?)
    end

    def protection_additions
      protection = @state.protection
      PROTECTION_ADDITIONS.select { |field| adds?(field, protection[field]) } unless protection.nil?
    end

    # Reviews add something only when any is required.
    def adds?(field, value)
      case value
      when nil then false
      when Hash then field != REVIEWS || value[Template::APPROVALS].to_i.positive?
      else true
      end
    end

    def file_fields
      rules_text = @state.files[VendoredPaths::RULES_FILE]
      { rules_header_ok: rules_text && rules_text.lines.first.to_s.include?(HEADER_MARK),
        rules_body: rules_text && rules_text.lines.drop(HEADER_LINES).join }
    end

    # None for a personal repository, whose instructions aren't read.
    def skill_fields
      scan = @state.skill_scan
      return { unshipped_skills: [], skills_unchecked: scan&.unchecked } if scan.nil? || scan.unchecked

      named = scan.texts.flat_map { |text| SkillMentions.names_in(text) }
      { unshipped_skills: (named - scan.shipped).uniq.sort, skills_unchecked: nil }
    end
  end
end

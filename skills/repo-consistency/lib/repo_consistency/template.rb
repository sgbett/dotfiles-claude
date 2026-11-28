# frozen_string_literal: true

require 'json'
require_relative 'projection'
require_relative 'ruleset_shape'
require_relative 'tier'

module RepoConsistency
  # A template file can't be read as the template needs it: missing, not a
  # regular file, or not a JSON object.
  class TemplateUnreadable < SkillSupport::Error
    attr_reader :file

    def initialize(file, why)
      @file = file
      super("#{file} #{why}")
    end
  end

  # The profile's enforcement assets, profiles/git-workflow, read from the
  # template directory and never restated here: the three ruleset request
  # bodies and the repository's, and the profile text beside the directory,
  # which a protected repository vendors.
  class Template
    DEFAULT_BRANCH_RULESET = 'ruleset.json'
    RULESETS = [DEFAULT_BRANCH_RULESET, 'ruleset-project-release.json', 'ruleset-tags.json'].freeze
    REPOSITORY = 'repository.json'
    PROFILE = '../git-workflow.md'
    PULL_REQUEST = 'pull_request'
    MERGE_METHODS = 'allowed_merge_methods'
    APPROVALS = 'required_approving_review_count'
    # GitHub fills this with true when a request omits it, which with no
    # required approvals and a sole owner demands an approval nobody can
    # give, so the template pins it and the audit compares it.
    EXTRA_APPROVAL = 'require_extra_approval_for_unattributed_changes'
    # The profile's first rule. The ruleset targets ~DEFAULT_BRANCH, so a
    # repository still on main is covered by it and reported here.
    DEFAULT_BRANCH = 'master'

    attr_reader :repository_flags, :profile

    def self.load(directory)
      new(directory).load
    end

    def initialize(directory)
      @directory = directory
    end

    def load
      @rulesets = RULESETS.to_h { |file| [file, json(file)] }
      @repository_flags = json(REPOSITORY)
      @profile = text(PROFILE)
      self
    end

    def rulesets
      @rulesets.values
    end

    # The rules the template puts on the default branch, as GitHub lists
    # them in force.
    def rules
      Array(@rulesets.fetch(DEFAULT_BRANCH_RULESET)['rules'])
    end

    def rule_types
      rules.map { |rule| rule['type'] }
    end

    # The template as a protected repository that applied it stands: its
    # rulesets alone in force, granting no bypass; its flags set; the
    # profile vendored under the header the runbook gives; no tier line;
    # and no skill named that it doesn't ship.
    def projection
      parameters = rules.find { |rule| rule['type'] == PULL_REQUEST }.fetch('parameters')
      Projection.new(default_branch: DEFAULT_BRANCH, tier: Tier::PROTECTED, tier_word: nil, difference: nil,
                     rulesets_available: true, rule_types: rule_types, merge_methods: parameters[MERGE_METHODS],
                     approvals: parameters[APPROVALS], extra_approval: parameters[EXTRA_APPROVAL],
                     rulesets: ruleset_shapes, pull_requests_required: true,
                     ruleset_bypasses: [], flags: @repository_flags, protection_additions: nil,
                     rules_header_ok: true, rules_body: @profile, unshipped_skills: [], skills_unchecked: nil)
    end

    private

    # The rules in force on the default branch are checked too, so what a
    # line on them reports is left out of comparing its ruleset, or one defect
    # would be reported twice.
    def ruleset_shapes
      @rulesets.to_h do |file, ruleset|
        shape = RulesetShape.of(ruleset)
        shape.leave_to_rules_in_force if file == DEFAULT_BRANCH_RULESET
        [ruleset['name'], shape]
      end
    end

    def json(file)
      parsed = JSON.parse(text(file))
      raise TemplateUnreadable.new(file, 'is not a JSON object') unless parsed.is_a?(Hash)

      parsed
    rescue JSON::ParserError
      raise TemplateUnreadable.new(file, 'is not JSON')
    end

    def text(file)
      SkillSupport::WrittenFile.read(File.join(@directory, file))
    rescue SkillSupport::UnusableFile
      raise TemplateUnreadable.new(file, 'is missing or not a regular file')
    end
  end
end

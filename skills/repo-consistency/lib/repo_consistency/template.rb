# frozen_string_literal: true

require 'json'
require_relative 'hooks_entry'
require_relative 'projection'
require_relative 'tier_line'

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
  # template directory and never restated here: the ruleset and repository
  # request bodies, the hook files and the settings entry that runs them,
  # and the profile text beside the directory, which a collaborative
  # repository vendors.
  class Template
    RULESET = 'ruleset.json'
    REPOSITORY = 'repository.json'
    HOOKS_SETTINGS = 'hooks.json'
    HOOK_FILES = %w[hooks/push-guard hooks/push-guard.rb].freeze
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

    attr_reader :repository_flags, :hooks_settings, :hooks, :profile

    def self.load(directory)
      new(directory).load
    end

    def initialize(directory)
      @directory = directory
    end

    def load
      @ruleset = json(RULESET)
      @repository_flags = json(REPOSITORY)
      @hooks_settings = json(HOOKS_SETTINGS)
      @hooks = HOOK_FILES.to_h { |file| [File.basename(file), text(file)] }
      @profile = text(PROFILE)
      self
    end

    def ruleset_name
      @ruleset['name']
    end

    # The rules the template puts on the default branch, as GitHub lists
    # them in force.
    def rules
      Array(@ruleset['rules'])
    end

    def rule_types
      rules.map { |rule| rule['type'] }
    end

    # The template as a repository that applied it stands: its ruleset
    # alone in force on master, granting no bypass; its flags set; the hook
    # files and the settings entry vendored; the profile vendored under the
    # header the runbook gives; and the tier declared collaborative.
    def projection
      parameters = rules.find { |rule| rule['type'] == PULL_REQUEST }.fetch('parameters')
      Projection.new(default_branch: DEFAULT_BRANCH, tier: TierLine::COLLABORATIVE, difference: nil,
                     rulesets_available: true, rule_types: rule_types, merge_methods: parameters[MERGE_METHODS],
                     approvals: parameters[APPROVALS], extra_approval: parameters[EXTRA_APPROVAL],
                     ruleset_names: [ruleset_name], ruleset_bypasses: [],
                     flags: @repository_flags, protection_additions: nil, rules_header_ok: true,
                     rules_body: @profile, hooks: @hooks, hooks_entry: HooksEntry.of_settings(@hooks_settings))
    end

    private

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

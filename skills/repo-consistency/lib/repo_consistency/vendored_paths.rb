# frozen_string_literal: true

module RepoConsistency
  # Where a collaborative repository keeps its vendored copies of the
  # profile's assets, and the file that declares its tier, all read on its
  # default branch.
  module VendoredPaths
    CLAUDE_MD = 'CLAUDE.md'
    RULES_FILE = '.claude/rules/git-workflow.md'
    HOOK_FILES = %w[.claude/hooks/push-guard .claude/hooks/push-guard.rb].freeze
    SETTINGS_FILE = '.claude/settings.json'
    ALL = [CLAUDE_MD, RULES_FILE, *HOOK_FILES, SETTINGS_FILE].freeze
  end
end

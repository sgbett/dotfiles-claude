# frozen_string_literal: true

module RepoConsistency
  # The files the audit reads on a repository's default branch: CLAUDE.md,
  # which may carry a tier line, and the vendored copy of the profile, whose
  # presence makes the repository protected (Tier).
  module VendoredPaths
    CLAUDE_MD = 'CLAUDE.md'
    RULES_FILE = '.claude/rules/git-workflow.md'
    ALL = [CLAUDE_MD, RULES_FILE].freeze
  end
end

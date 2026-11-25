# frozen_string_literal: true

require_relative 'vendored_paths'

module RepoConsistency
  # A repository's git tier, decided by one fact the profile names as the
  # declaration: the vendored rules file on its default branch. Never by a
  # tier line, which only states a difference.
  module Tier
    PROTECTED = 'protected'
    PERSONAL = 'personal'

    module_function

    # +files+ are the vendored files' texts by path, nil for one missing.
    def of(files)
      files[VendoredPaths::RULES_FILE].nil? ? PERSONAL : PROTECTED
    end
  end
end

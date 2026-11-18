# frozen_string_literal: true

module RepoConsistency
  # What GitHub says of one repository, as RepositoryReader reads it and
  # before RepositoryProjection maps it: the flags the template sets, the
  # rules in force on the default branch, each ruleset's detail, the classic
  # protection (nil for none), whether the plan allows rulesets at all, and
  # each vendored file's text by path (nil when missing).
  RepositoryState = Struct.new(:repository, :default_branch, :flags, :rules, :rulesets, :protection,
                               :rulesets_available, :files, keyword_init: true)
end

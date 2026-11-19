# frozen_string_literal: true

module RepoConsistency
  # What GitHub says of one repository, as RepositoryReader reads it and
  # before RepositoryProjection maps it: the flags the template sets, the
  # rules in force on the default branch, each ruleset's detail, the classic
  # protection (nil for none), whether the plan allows rulesets at all,
  # each vendored file's text by path (nil when missing), and the SkillScan
  # (nil for a personal repository, which isn't scanned).
  RepositoryState = Struct.new(:repository, :default_branch, :flags, :rules, :rulesets, :protection,
                               :rulesets_available, :files, :skill_scan, keyword_init: true)
end

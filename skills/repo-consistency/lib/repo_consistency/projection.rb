# frozen_string_literal: true

module RepoConsistency
  # The fields the audit compares, in one shape for both sides: the
  # template as a repository that applied it would stand
  # (Template#projection), and a live repository as GitHub answers for it
  # (RepositoryProjection). Drift is the difference between two of these,
  # so the template projected onto itself has none.
  #
  # rule_types are the rules in force on the default branch; merge_methods
  # and approvals are the pull_request rule's, nil when there is none;
  # bypassing_rulesets pairs each ruleset granting a bypass with its name;
  # protection_additions is nil without a classic protection, else what it
  # adds beyond the template, so [] for a redundant one; rules_body is the
  # vendored rules file after its header, nil when the file is missing;
  # hooks maps each hook file's name to its text, nil when missing;
  # hooks_entry is HooksEntry's answer for the settings file.
  Projection = Struct.new(:default_branch, :tier, :difference, :rulesets_available, :rule_types, :merge_methods,
                          :approvals, :ruleset_names, :bypassing_rulesets, :flags, :protection_additions,
                          :rules_header_ok, :rules_body, :hooks, :hooks_entry, keyword_init: true)
end

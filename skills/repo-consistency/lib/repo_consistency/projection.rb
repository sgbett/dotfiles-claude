# frozen_string_literal: true

module RepoConsistency
  # The fields the audit compares, in one shape for both sides: the
  # template as a repository that applied it would stand
  # (Template#projection), and a live repository as GitHub answers for it
  # (RepositoryProjection). Drift is the difference between two of these,
  # so the template projected onto itself has none.
  #
  # tier is Tier's, from the rules file; tier_word and difference are the
  # tier line's, nil without one; rule_types are the rules in force on the
  # default branch; merge_methods, approvals and extra_approval (for
  # unattributed changes) are the pull_request rule's, nil when there is
  # none; rulesets maps each ruleset's name to its RulesetShape, the first
  # of a name standing for it; ruleset_bypasses lists, by id and name, each
  # ruleset whose bypass actors are granted or unreadable, and which of the
  # two; protection_additions is nil without a classic protection, else
  # what it adds beyond the template, so [] for a redundant one;
  # rules_body is the vendored rules file after its header, nil when the
  # file is missing; unshipped_skills lists, sorted, each of UserSkills'
  # names the instruction files invoke that the repository doesn't ship;
  # skills_unchecked is nil, or the SkillScan's reason the files went
  # unchecked, unshipped_skills then being [].
  Projection = Struct.new(:default_branch, :tier, :tier_word, :difference, :rulesets_available, :rule_types,
                          :merge_methods, :approvals, :extra_approval, :rulesets, :ruleset_bypasses, :flags,
                          :protection_additions, :rules_header_ok, :rules_body, :unshipped_skills,
                          :skills_unchecked, keyword_init: true)
end

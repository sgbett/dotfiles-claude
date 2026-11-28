# frozen_string_literal: true

module RepoConsistency
  # git-settings was called with arguments it doesn't take.
  class UsageError < SkillSupport::Error
    USAGE = [
      'usage: git-settings audit <owner/repo> [<owner/repo> ...] [--template-dir <dir>] [--hostname <host>]',
      'where the template directory holds ruleset.json, ruleset-project-release.json, ruleset-tags.json and',
      'repository.json, with the profile git-workflow.md beside it: profiles/git-workflow of the repository that',
      'holds this skill unless given, and the host is github.com unless given'
    ].join("\n").freeze

    def initialize
      super(USAGE)
    end
  end
end

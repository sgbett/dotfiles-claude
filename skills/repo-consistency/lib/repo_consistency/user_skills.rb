# frozen_string_literal: true

module RepoConsistency
  # The skills and commands this repository installs at user level, by the
  # name a session invokes each one: a skill by its directory under skills/,
  # a command by its path under commands/ without .md, a nested one joined
  # with a colon (commands/project/generate.md is project:generate).
  # Restated rather than listed from skills/ at run time: an installation's
  # skills/ holds untracked skills beside these, and the vendored ones are
  # symlinks that dangle where vendor/ isn't cloned. user_skills_spec.rb
  # holds the lists to what git tracks.
  module UserSkills
    SKILLS = %w[
      architecture-review architecture-status copilot-check create-adr do list-members new-project-rails
      pragmatic-guard read-email repo-consistency repo-security-clean repo-security-purge repo-security-scan
      setup-architect specialist-review zendesk
    ].freeze
    COMMANDS = %w[config-cleaner deslop dotfiles-setup project:generate transcript].freeze
    NAMES = (SKILLS + COMMANDS).freeze
  end
end

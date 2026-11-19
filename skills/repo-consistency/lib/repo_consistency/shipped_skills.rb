# frozen_string_literal: true

require_relative 'skill_paths'
require_relative 'tree_entry'
require_relative 'user_skills'

module RepoConsistency
  # Which of UserSkills' names a repository ships, from its tree: a skill
  # by .claude/skills/<name>/SKILL.md, a command by
  # .claude/commands/<name>.md. The tree records a link as a file whatever
  # its target, so a shipping file that is a link ships only if a contents
  # read resolves it, which the caller makes for each of #links.
  class ShippedSkills
    # +entries+ maps each path of the tree to its entry.
    def initialize(entries)
      @entries = entries
    end

    # The shipping files that are links, in path order.
    def links
      UserSkills::NAMES.flat_map { |name| SkillPaths.shipping_files(name) }
                       .select { |path| TreeEntry.link?(@entries[path]) }.sort
    end

    # +resolved+ are the links that resolve to a file in the repository.
    def names(resolved)
      UserSkills::NAMES.select do |name|
        SkillPaths.shipping_files(name).any? do |path|
          entry = @entries[path]
          TreeEntry.file?(entry) && (!TreeEntry.link?(entry) || resolved.include?(path))
        end
      end
    end
  end
end

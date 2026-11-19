# frozen_string_literal: true

require_relative 'user_skills'

module RepoConsistency
  # Where, as paths of a repository's tree, Claude Code finds the
  # instructions it loads into every session (CLAUDE.md, .claude/CLAUDE.md
  # and each Markdown file under .claude/rules/ at any depth) and the skills
  # and commands the repository ships. Instruction files are matched
  # ignoring case, as a case-insensitive file system loads claude.md or
  # .Claude/rules/x.MD all the same; a shipping path is exact, since a
  # skill's name is its directory's.
  module SkillPaths
    CLAUDE_DIRECTORY = '.claude'
    INSTRUCTION_FILES = %w[claude.md .claude/claude.md].freeze
    RULES = '.claude/rules/'
    SKILLS = '.claude/skills/'
    COMMANDS = '.claude/commands/'
    MARKDOWN = '.md'
    # A link in place of one of these directories leaves the tree silent on
    # everything a checkout would find inside it.
    DIRECTORIES = %w[.claude .claude/rules .claude/skills .claude/commands].freeze

    module_function

    # Whether +path+, an entry of the root tree, is the .claude directory.
    def claude_directory?(path)
      path.casecmp?(CLAUDE_DIRECTORY)
    end

    def instruction_file?(path)
      folded = path.downcase
      INSTRUCTION_FILES.include?(folded) || (folded.start_with?(RULES) && folded.end_with?(MARKDOWN))
    end

    # The directory that ships +name+ as a skill.
    def skill_directory(name)
      "#{SKILLS}#{name}"
    end

    # The file that ships +name+ as a command, a colon standing for a
    # directory.
    def command_file(name)
      "#{COMMANDS}#{name.tr(':', '/')}#{MARKDOWN}"
    end

    # Whether a symlink, or with +submodule+ a submodule, at +path+ would
    # hide from the tree an instruction file, a skill or command the
    # repository ships, or a directory holding them. A symlink named as a
    # Markdown file stands for a file, which the contents API reads through
    # when its target is in the repository; any other could stand for a
    # directory, a link's name not saying which. A submodule is always one.
    def hides_from_tree?(path, submodule:)
      watched?(path) && (submodule || !path.downcase.end_with?(MARKDOWN))
    end

    # Anything under rules/ or commands/ could be one of those. Under
    # skills/, only an entry named as a user-level skill could hide one the
    # repository ships; a repository's own linked skill hides nothing.
    def watched?(path)
      folded = path.downcase
      INSTRUCTION_FILES.include?(folded) || DIRECTORIES.include?(folded) || folded.start_with?(RULES, COMMANDS) ||
        (folded.start_with?(SKILLS) && UserSkills::NAMES.include?(path[SKILLS.length..]))
    end

    private_class_method :watched?
  end
end

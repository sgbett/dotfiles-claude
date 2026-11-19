# frozen_string_literal: true

module RepoConsistency
  # Where, as paths of a repository's tree, Claude Code finds the
  # instructions it loads into every session (CLAUDE.md, .claude/CLAUDE.md
  # and each Markdown file under .claude/rules/ at any depth) and the skills
  # and commands the repository ships.
  module SkillPaths
    INSTRUCTION_FILES = %w[CLAUDE.md .claude/CLAUDE.md].freeze
    RULES = '.claude/rules/'
    SKILLS = '.claude/skills/'
    COMMANDS = '.claude/commands/'
    MARKDOWN = '.md'
    # A link in place of one of these directories leaves the tree silent on
    # everything a checkout would find inside it.
    DIRECTORIES = %w[.claude .claude/rules .claude/skills .claude/commands].freeze

    module_function

    def instruction_file?(path)
      INSTRUCTION_FILES.include?(path) || (path.start_with?(RULES) && path.end_with?(MARKDOWN))
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
      watched?(path) && (submodule || !path.end_with?(MARKDOWN))
    end

    # Anything under rules/ or commands/ could be one of those, but only
    # skills/' own entries are skills.
    def watched?(path)
      INSTRUCTION_FILES.include?(path) || DIRECTORIES.include?(path) || path.start_with?(RULES, COMMANDS) ||
        (path.start_with?(SKILLS) && !path.delete_prefix(SKILLS).include?('/'))
    end

    private_class_method :watched?
  end
end

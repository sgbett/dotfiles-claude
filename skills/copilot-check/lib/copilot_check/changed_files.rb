# frozen_string_literal: true

require_relative 'rest_list'

module CopilotCheck
  # The paths a pull request changes, read through REST, which alone gives a
  # renamed file's previous path; and those that change what GitHub Actions
  # runs, what Claude Code loads from a checkout, or the instructions
  # Copilot reviews with: its rubric, its path-specific instructions, its
  # agent skills (under .github/skills/, .agents/skills/ or .claude/skills/)
  # and the other files it takes instructions from. Copilot reads them from
  # the head, so a pull request that changes them steers its own review and,
  # once merged, every later one, as the rubric's "## Do not flag" list
  # filters out findings from them all.
  class ChangedFiles
    # GitHub lists at most 3,000 of a pull request's files.
    MAX_PAGES = 30
    WORKFLOW_DIRECTORIES = %w[.github/workflows/ .github/actions/].freeze
    RUBRIC = '.github/copilot-instructions.md'
    # Copilot code review's path-specific instructions, *.instructions.md.
    INSTRUCTIONS_DIRECTORY = '.github/instructions/'
    # Where GitHub says a project keeps the agent skills Copilot code review
    # reads, each a directory holding a SKILL.md, besides .claude/skills/,
    # which RULES_DIRECTORY covers.
    SKILLS_DIRECTORIES = %w[.github/skills/ .agents/skills/].freeze
    # What Claude Code loads from a checkout: its rules, local rules and
    # project MCP servers. Copilot code review reads CLAUDE.md too.
    CLAUDE_FILES = %w[CLAUDE.md CLAUDE.local.md .mcp.json].freeze
    # The other files Copilot code review takes instructions from.
    COPILOT_FILES = %w[AGENTS.md GEMINI.md REVIEW.md].freeze
    RULES_DIRECTORY = '.claude'
    PROTECTED_DIRECTORIES = [*WORKFLOW_DIRECTORIES, INSTRUCTIONS_DIRECTORY, *SKILLS_DIRECTORIES].freeze
    PROTECTED_NAMES = [*CLAUDE_FILES, *COPILOT_FILES].freeze

    # +paths+ are each file's path and a renamed file's previous one;
    # +complete+ whether they cover every file the pull request changes.
    Result = Struct.new(:paths, :complete, keyword_init: true) do
      def protected_paths
        paths.select { |path| ChangedFiles.protected?(path) }
      end
    end

    # Whether +path+ is under .github/workflows/, .github/actions/,
    # .github/instructions/, .github/skills/ or .agents/skills/, is
    # .github/copilot-instructions.md, is a file named CLAUDE.md,
    # CLAUDE.local.md, .mcp.json, AGENTS.md, GEMINI.md or REVIEW.md, or is
    # under a .claude directory, those last two at any depth, as Claude Code
    # can start in any directory of a checkout and GitHub doesn't say where
    # Copilot looks for each. Case is ignored, as a case-insensitive file
    # system ignores it.
    def self.protected?(path)
      name = File.basename(path)
      PROTECTED_DIRECTORIES.any? { |directory| path.downcase.start_with?(directory) } || path.casecmp?(RUBRIC) ||
        PROTECTED_NAMES.any? { |protected_name| name.casecmp?(protected_name) } ||
        path.split('/')[0...-1].any? { |directory| directory.casecmp?(RULES_DIRECTORY) }
    end

    # +github+ is the SkillSupport::Gh for the repository's host.
    def initialize(github)
      @github = github
    end

    # The Result for pull request +number+ of +repository+ ("owner/repo"),
    # which GitHub says changes +changed_files+ files.
    def list(repository, number, changed_files:)
      path = "repos/#{SkillSupport::Identifiers.repository!(repository)}/pulls/" \
             "#{SkillSupport::Identifiers.issue_number!(number)}/files"
      entries, whole = RestList.read(@github, path, max_pages: MAX_PAGES)
      Result.new(paths: entries.flat_map { |entry| paths(entry) }.uniq,
                 complete: whole && entries.length == changed_files)
    end

    private

    def paths(entry)
      paths = [entry['filename'], *entry['previous_filename']] if entry.is_a?(Hash)
      unless paths&.all? { |path| path.is_a?(String) && !path.empty? }
        raise SkillSupport::UnexpectedResponse, "a pull request's file came back without its path"
      end

      paths
    end
  end
end

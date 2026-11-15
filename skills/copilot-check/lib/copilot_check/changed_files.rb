# frozen_string_literal: true

require_relative 'rest_list'

module CopilotCheck
  # The paths a pull request changes, read through REST, which alone gives a
  # renamed file's previous path; and those that change what GitHub Actions
  # runs, what Claude Code loads from a checkout, or the rubric Copilot
  # reviews against. The reviewer's own rubric mustn't change unattended,
  # as its "## Do not flag" list filters out findings from every later
  # review.
  class ChangedFiles
    # GitHub lists at most 3,000 of a pull request's files.
    MAX_PAGES = 30
    WORKFLOW_DIRECTORIES = %w[.github/workflows/ .github/actions/].freeze
    RUBRIC = '.github/copilot-instructions.md'
    # What Claude Code loads from a checkout: its rules, local rules and
    # project MCP servers.
    CLAUDE_FILES = %w[CLAUDE.md CLAUDE.local.md .mcp.json].freeze
    RULES_DIRECTORY = '.claude'

    # +paths+ are each file's path and a renamed file's previous one;
    # +complete+ whether they cover every file the pull request changes.
    Result = Struct.new(:paths, :complete, keyword_init: true) do
      def protected_paths
        paths.select { |path| ChangedFiles.protected?(path) }
      end
    end

    # Whether +path+ is under .github/workflows/ or .github/actions/, is
    # .github/copilot-instructions.md, is a file named CLAUDE.md,
    # CLAUDE.local.md or .mcp.json, or is under a .claude directory, the
    # last three at any depth, as Claude Code can start in any directory of
    # a checkout. Case is ignored, as a case-insensitive file system ignores
    # it.
    def self.protected?(path)
      directories = path.split('/')[0...-1]
      WORKFLOW_DIRECTORIES.any? { |directory| path.downcase.start_with?(directory) } || path.casecmp?(RUBRIC) ||
        CLAUDE_FILES.any? { |name| File.basename(path).casecmp?(name) } ||
        directories.any? { |name| name.casecmp?(RULES_DIRECTORY) }
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

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
    # which CLAUDE_DIRECTORY covers.
    SKILLS_DIRECTORIES = %w[.github/skills/ .agents/skills/].freeze
    # What Claude Code loads from a checkout: its rules, local rules and
    # project MCP servers. Copilot code review reads CLAUDE.md too.
    CLAUDE_FILES = %w[CLAUDE.md CLAUDE.local.md .mcp.json].freeze
    # The other files Copilot code review takes instructions from.
    COPILOT_FILES = %w[AGENTS.md GEMINI.md REVIEW.md].freeze
    CLAUDE_DIRECTORY = '.claude'
    PLANS_DIRECTORY = 'plans'
    # Segments git never records in a path, and that could make one resolve
    # elsewhere than it reads.
    UNRESOLVED_SEGMENTS = ['', '.', '..'].freeze
    # HFS+ ignores default-ignorable code points in a name, so .claude with
    # U+200C inside it opens as .claude. Removing them all, not only those
    # HFS+ ignores, can only protect more.
    IGNORABLE = /\p{Default_Ignorable_Code_Point}/
    # NTFS drops a name's trailing dots and spaces, so CLAUDE.md. opens as
    # CLAUDE.md.
    TRAILING_DOTS_AND_SPACES = /[. ]+\z/
    PROTECTED_DIRECTORIES = [*WORKFLOW_DIRECTORIES, INSTRUCTIONS_DIRECTORY, *SKILLS_DIRECTORIES].freeze
    PROTECTED_NAMES = [*CLAUDE_FILES, *COPILOT_FILES].freeze

    # +paths+ are each file's path and a renamed file's previous one;
    # +complete+ whether they cover every file the pull request changes.
    Result = Struct.new(:paths, :complete, keyword_init: true) do
      def protected_paths
        paths.select { |path| ChangedFiles.protected?(path) }
      end
    end

    # Whether +path+ is, or is under, .github/workflows/, .github/actions/,
    # .github/instructions/, .github/skills/ or .agents/skills/, is
    # .github/copilot-instructions.md, is a file named CLAUDE.md,
    # CLAUDE.local.md, .mcp.json, AGENTS.md, GEMINI.md or REVIEW.md, or is,
    # or is under, a .claude directory other than as a plan in its plans/,
    # those last two at any depth, as Claude Code can start in any directory
    # of a checkout and GitHub doesn't say where Copilot looks for each.
    # Claude Code doesn't load a plan as configuration: an agent reads one
    # once it is merged or when asked to, so a plan doesn't steer the
    # pull request's own promotion (#33). A pull request's files are never
    # directories, so one at a directory's own path is a symlink or submodule
    # in its place. Each segment is compared as some file system may open
    # it, so that a path one opens as a protected path is held: case is
    # ignored, and default-ignorable code points and trailing dots and
    # spaces are removed. 8.3 short names such as CLAUDE~1.MD aren't
    # covered: whether a volume has them, and what each is, depends on the
    # volume.
    def self.protected?(path)
      parts = path.split('/', -1)
      normalised = parts.map { |part| normalise(part) }
      joined = normalised.join('/')
      name = File.basename(joined)
      PROTECTED_DIRECTORIES.any? { |directory| "#{joined.downcase}/".start_with?(directory) } ||
        joined.casecmp?(RUBRIC) || PROTECTED_NAMES.any? { |protected_name| name.casecmp?(protected_name) } ||
        under_claude_directory?(parts, normalised)
    end

    def self.normalise(segment)
      segment.gsub(IGNORABLE, '').sub(TRAILING_DOTS_AND_SPACES, '')
    end

    # Whether some segment of +normalised+, the normalised +parts+, is
    # .claude and isn't followed by a plans segment with more after it. The
    # exemption takes the .claude and plans segments as they are in +parts+,
    # so a segment that only normalises to either is held, the safe side, as
    # only some file systems open it as that directory. A path with
    # a segment that is, or normalises to, empty, . or .. gets no exemption,
    # as it may resolve to something other than a plan.
    # Warning: the exemption assumes nothing in the base that Claude Code
    # loads or runs reaches into plans/: an import such as
    # @.claude/plans/x.md in a CLAUDE.md, a symlink from a loaded place such
    # as .claude/rules/x.md -> ../plans/x.md, or a hook, statusLine or MCP
    # server command in the settings or .mcp.json that runs a script under
    # .claude/plans/. Any of these would load or run a plan the pull request
    # changes.
    def self.under_claude_directory?(parts, normalised)
      exemptible = ![*parts, *normalised].intersect?(UNRESOLVED_SEGMENTS)
      normalised.each_index.any? do |index|
        normalised[index].casecmp?(CLAUDE_DIRECTORY) && !(exemptible && plan_below?(parts, index))
      end
    end

    def self.plan_below?(parts, index)
      parts.length > index + 2 && parts[index].casecmp?(CLAUDE_DIRECTORY) &&
        parts[index + 1].casecmp?(PLANS_DIRECTORY)
    end

    private_class_method :normalise, :under_claude_directory?, :plan_below?

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
      unless paths&.all? { |path| path.is_a?(String) && !path.empty? && path.valid_encoding? }
        raise SkillSupport::UnexpectedResponse, "a pull request's file came back without its path"
      end

      paths
    end
  end
end

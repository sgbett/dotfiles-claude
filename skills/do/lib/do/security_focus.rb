# frozen_string_literal: true

require_relative 'focus_sections'

module Do
  # The security_focus `preflight check` gives the security gate: every
  # "## Security focus" section of this repository's CLAUDE.md and of each
  # file under .claude/rules/, as they stand at the base branch's commit.
  # Read through GitHub rather than the checkout, so the diff under review
  # can't change its own gate. Only a 404 means a file is absent; any other
  # failure is a tool failure.
  class SecurityFocus
    CLAUDE_MD = 'CLAUDE.md'
    RULES = '.claude/rules'
    # A symlink to a file reads as that file; RepositoryFiles refuses any other.
    FILE_TYPES = %w[file symlink].freeze
    CONTROL_CHARACTER = /[[:cntrl:]]/

    # +sources+ are the paths the sections came from, CLAUDE.md first and
    # then the rules in path order; +text+ is every section, in that order.
    Result = Struct.new(:sources, :text, keyword_init: true) do
      def found?
        !sources.empty?
      end
    end

    # +files+ is a SkillSupport::RepositoryFiles on the issue's host.
    def initialize(files)
      @files = files
    end

    # The Result for +repository+ at +ref+, a commit.
    def read(repository, ref)
      sources = []
      sections = []
      documents(repository, ref).each do |path, text|
        found = FocusSections.extract(text)
        next if found.empty?

        sources << path
        sections.concat(found)
      end
      Result.new(sources: sources, text: sections.join("\n\n"))
    end

    private

    # [path, text] for each document that exists.
    def documents(repository, ref)
      [[CLAUDE_MD, file(repository, CLAUDE_MD, ref)], *rules(repository, RULES, ref)].select { |_path, text| text }
    end

    def file(repository, path, ref)
      content = @files.read(repository, path, ref: ref)
      raise SkillSupport::UnexpectedResponse, "#{path} is a directory, not a file" if content.is_a?(Array)

      content
    end

    def rules(repository, directory, ref)
      listing = @files.read(repository, directory, ref: ref)
      return [] if listing.nil?
      raise SkillSupport::UnexpectedResponse, "#{directory} is a file, not a directory" unless listing.is_a?(Array)

      listing.map { |entry| [checked_path(directory, entry), entry['type']] }.sort.flat_map do |path, type|
        listed(repository, path, type, ref)
      end
    end

    def listed(repository, path, type, ref)
      return rules(repository, path, ref) if type == 'dir'
      return [[path, file(repository, path, ref)]] if FILE_TYPES.include?(type)

      raise SkillSupport::UnexpectedResponse, "#{path} is a #{type}, not a file or directory"
    end

    # A path the listing gives must be an entry of the directory listed.
    def checked_path(directory, entry)
      path = entry['path'] if entry.is_a?(Hash)
      unless path.is_a?(String) && path.start_with?("#{directory}/") && !CONTROL_CHARACTER.match?(path)
        raise SkillSupport::UnexpectedResponse, "the listing of #{directory} names an entry outside it"
      end

      path
    end
  end
end

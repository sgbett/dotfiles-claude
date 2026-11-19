# frozen_string_literal: true

require_relative 'skill_paths'
require_relative 'skill_scan'
require_relative 'tier_line'
require_relative 'user_skills'
require_relative 'vendored_paths'

module RepoConsistency
  # Reads what the skill-name check compares, for a repository whose
  # CLAUDE.md doesn't declare it personal, in a fixed order so that a spec
  # can match every call: the default branch's whole tree, then each
  # instruction file it lists that RepositoryReader hasn't read already, in
  # path order. A personal repository costs no read. A tree that can't show
  # everything, or a file the contents API refuses, leaves the check
  # unchecked rather than stopping the audit, as the repository's other
  # drift stands without it.
  class SkillScanReader
    SYMLINK_MODE = '120000'
    SUBMODULE_TYPE = 'commit'
    DIRECTORY_TYPE = 'tree'
    FILE_TYPE = 'blob'

    # +files+ are RepositoryReader's texts by path, CLAUDE.md's among them.
    def self.read(github, repository, branch:, files:)
      new(github, repository, branch: branch, files: files).read
    end

    def initialize(github, repository, branch:, files:)
      @github = github
      @repository = repository
      @branch = branch
      @files = files
    end

    # The SkillScan, or nil for a personal repository.
    def read
      return if TierLine.read(@files[VendoredPaths::CLAUDE_MD]).tier == TierLine::PERSONAL

      entries, truncated = tree
      return SkillScan.new(unchecked: :truncated) if truncated
      return SkillScan.new(unchecked: :linked) if entries.any? { |entry| hides?(entry) }

      scan(entries.to_h { |entry| entry.values_at('path', 'type') })
    end

    private

    def tree
      answer = @github.api("repos/#{@repository}/git/trees/#{SkillSupport::Gh.path_segment(@branch)}",
                           fields: { 'recursive' => '1' })
      entries = answer['tree'] if answer.is_a?(Hash)
      unless entries.is_a?(Array) && entries.all? { |entry| entry?(entry) }
        raise SkillSupport::UnexpectedResponse, "the tree of #{@repository} is not a list of entries"
      end

      [entries, answer['truncated'] == true]
    end

    def entry?(entry)
      entry.is_a?(Hash) && entry.values_at('path', 'mode', 'type').all?(String)
    end

    def hides?(entry)
      (entry['mode'] == SYMLINK_MODE || entry['type'] == SUBMODULE_TYPE) && SkillPaths.hides_from_tree?(entry['path'])
    end

    # +types+ maps each path of the tree to its type.
    def scan(types)
      paths = types.keys.select { |path| types[path] == FILE_TYPE && SkillPaths.instruction_file?(path) }.sort
      SkillScan.new(texts: paths.map { |path| text(path) }, shipped: shipped(types))
    rescue SkillSupport::UnexpectedResponse
      SkillScan.new(unchecked: :unreadable)
    end

    # RepositoryFiles raises UnexpectedResponse for a file it won't decode:
    # over the contents API's size limit, or not a file after all.
    def text(path)
      return @files[path] if @files.key?(path)

      content = files_reader.read(@repository, path, ref: @branch)
      raise SkillSupport::UnexpectedResponse, "#{path} is a directory" if content.is_a?(Array)

      content
    end

    def files_reader
      @files_reader ||= SkillSupport::RepositoryFiles.new(@github)
    end

    def shipped(types)
      UserSkills::NAMES.select do |name|
        types[SkillPaths.skill_directory(name)] == DIRECTORY_TYPE || types[SkillPaths.command_file(name)] == FILE_TYPE
      end
    end
  end
end

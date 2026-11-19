# frozen_string_literal: true

require_relative 'skill_paths'
require_relative 'skill_scan'
require_relative 'tier_line'
require_relative 'user_skills'
require_relative 'vendored_paths'

module RepoConsistency
  # Reads what the skill-name check compares, for a repository whose
  # CLAUDE.md doesn't declare it personal, in a fixed order so that a spec
  # can match every call: the default branch's root tree, the whole of its
  # .claude directory's, then each instruction file they list that
  # RepositoryReader hasn't read already, in path order. Only the root and
  # .claude are read, as a large repository's whole tree comes back
  # truncated. A personal repository costs no read. A tree that can't show
  # everything, or a file the contents API refuses, leaves the check
  # unchecked rather than stopping the audit, as the repository's other
  # drift stands without it.
  class SkillScanReader
    # Any other failure to read an instruction file: a tool failure whose
    # message names only the repository and how gh failed. Never the path,
    # which whoever can push to the default branch chooses, nor gh's
    # stderr, which repeats it.
    class FileReadFailed < SkillSupport::Error
      def initialize(repository, how)
        super("an instruction file of #{repository} could not be read: #{how}")
      end
    end

    # Gh raises UnexpectedResponse when gh prints something other than JSON,
    # as RepositoryFiles does for a file it refuses. The files are read
    # through this, so that only a refusal reads as an unreadable file.
    class OutputGuard
      def initialize(github, repository)
        @github = github
        @repository = repository
      end

      def api(path, **options)
        @github.api(path, **options)
      rescue SkillSupport::UnexpectedResponse
        raise FileReadFailed.new(@repository, 'gh printed something other than JSON')
      end
    end

    SYMLINK_MODE = '120000'
    SUBMODULE_TYPE = 'commit'
    DIRECTORY_TYPE = 'tree'
    FILE_TYPE = 'blob'
    # A git object id, SHA-1 or SHA-256. A tree's id comes from GitHub and
    # goes into an API path.
    OBJECT_ID = /\A(?:[0-9a-f]{40}|[0-9a-f]{64})\z/
    # Each instruction file not already read costs a contents GET, from the
    # rate limit the whole estate's audit shares, so a repository with more
    # goes unchecked rather than spending it.
    MAX_FILE_READS = 200

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

      entries = tree
      return SkillScan.new(unchecked: :truncated) if entries.nil?
      return SkillScan.new(unchecked: :linked) if entries.any? { |entry| hides?(entry) }

      scan(entries.to_h { |entry| entry.values_at('path', 'type') })
    end

    private

    # The root's entries, then each .claude directory's under their full
    # paths; nil when GitHub cuts any of the listings off.
    def tree
      root = listing(SkillSupport::Gh.path_segment(@branch))
      return unless root

      claude_directories(root).inject(root) do |entries, directory|
        nested = listing(tree_id!(directory['sha']), recursive: true)
        break unless nested

        entries + nested.map { |entry| entry.merge('path' => "#{directory['path']}/#{entry['path']}") }
      end
    end

    def claude_directories(root)
      root.select { |entry| entry['type'] == DIRECTORY_TYPE && SkillPaths.claude_directory?(entry['path']) }
          .sort_by { |entry| entry['path'] }
    end

    # The entries of the tree +reference+ names, or nil when the listing is
    # truncated.
    def listing(reference, recursive: false)
      fields = recursive ? { 'recursive' => '1' } : {}
      answer = @github.api("repos/#{@repository}/git/trees/#{reference}", fields: fields)
      entries = answer['tree'] if answer.is_a?(Hash)
      unless entries.is_a?(Array) && entries.all? { |entry| entry?(entry) }
        raise SkillSupport::UnexpectedResponse, "a tree of #{@repository} is not a list of entries"
      end

      entries unless answer['truncated'] == true
    end

    def tree_id!(sha)
      return sha if sha.is_a?(String) && OBJECT_ID.match?(sha)

      raise SkillSupport::UnexpectedResponse, "a tree of #{@repository} lists a directory without a valid object id"
    end

    def entry?(entry)
      entry.is_a?(Hash) && entry.values_at('path', 'mode', 'type').all?(String)
    end

    def hides?(entry)
      submodule = entry['type'] == SUBMODULE_TYPE
      (submodule || entry['mode'] == SYMLINK_MODE) && SkillPaths.hides_from_tree?(entry['path'], submodule: submodule)
    end

    # +types+ maps each path of the tree to its type.
    def scan(types)
      paths = types.keys.select { |path| types[path] == FILE_TYPE && SkillPaths.instruction_file?(path) }.sort
      return SkillScan.new(unchecked: :too_many) if paths.count { |path| !@files.key?(path) } > MAX_FILE_READS

      SkillScan.new(texts: paths.map { |path| text(path) }, shipped: shipped(types))
    rescue SkillSupport::UnexpectedResponse
      SkillScan.new(unchecked: :unreadable)
    end

    # RepositoryFiles raises UnexpectedResponse for a file it won't decode:
    # over the contents API's size limit, or not a file, as a symlink out of
    # the repository is, which the API doesn't follow.
    def text(path)
      return @files[path] if @files.key?(path)

      content = read_file(path)
      raise SkillSupport::UnexpectedResponse, "#{path} is a directory" if content.is_a?(Array)

      content
    end

    # RepositoryFiles answers a 404 Not Found with nil and raises any other
    # GhError, whose message holds the arguments and so the path.
    def read_file(path)
      files_reader.read(@repository, path, ref: @branch)
    rescue SkillSupport::GhError => e
      raise FileReadFailed.new(@repository, e.http_status ? "gh answered HTTP #{e.http_status}" : 'gh failed')
    end

    def files_reader
      @files_reader ||= SkillSupport::RepositoryFiles.new(OutputGuard.new(@github, @repository))
    end

    def shipped(types)
      UserSkills::NAMES.select do |name|
        types[SkillPaths.skill_directory(name)] == DIRECTORY_TYPE || types[SkillPaths.command_file(name)] == FILE_TYPE
      end
    end
  end
end

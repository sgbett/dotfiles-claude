# frozen_string_literal: true

require_relative 'script_calls'
require_relative '../../lib/repo_consistency/tier_line'
require_relative '../../lib/repo_consistency/vendored_paths'

module RepoConsistency
  module Testing
    # The answers one repository gives the skill-name check's reads: its
    # recursive tree, in the recorded shape, listing each of its files and
    # their directories, then +extras+ (a submodule, say), cut off when
    # +truncated+; then the contents read of each instruction file the
    # vendored reads didn't cover. A file +symlinked+ names is a symlink in
    # the tree whose contents read, as GitHub's does for a target in the
    # repository, gives the target's text; one +escaping+ names, a symlink
    # out of the repository, which the API answers as a symlink. One
    # +oversized+ names is answered as GitHub answers for a file over 1 MB.
    class TreeAnswers
      include ScriptCalls

      FILE_MODE = '100644'
      SYMLINK_MODE = '120000'
      DIRECTORY_MODE = '040000'
      SHA = '0' * 40

      attr_accessor :extras, :truncated, :symlinked, :escaping, :oversized

      def initialize
        @extras = []
        @truncated = false
        @symlinked = []
        @escaping = []
        @oversized = []
      end

      # The entries for +repository+ at +branch+, whose files are +files+ by
      # path; none when CLAUDE.md declares it personal. A spec whose scan
      # stops early, on a truncated tree, a link where it looks or an
      # oversized file, has no instruction file to read after that point, so
      # these needn't know where the reader stops.
      def entries(repository, branch, files)
        return [] if TierLine.read(files[VendoredPaths::CLAUDE_MD]).tier == TierLine::PERSONAL

        reads = unread_instruction_files(files.keys).map do |path|
          entry(contents_call(repository, path, branch), **file_answer(path, files[path]))
        end
        [entry(tree_call(repository, branch), stdout: JSON.generate(response(files.keys))), *reads]
      end

      private

      def unread_instruction_files(paths)
        instruction_files = paths.select do |path|
          path == '.claude/CLAUDE.md' || (path.start_with?('.claude/rules/') && path.end_with?('.md'))
        end
        (instruction_files - VendoredPaths::ALL).sort
      end

      def file_answer(path, text)
        response = file_response(path, text)
        response = response.merge('encoding' => 'none', 'content' => '') if oversized.include?(path)
        response = escaping_link(path) if escaping.include?(path)
        { stdout: JSON.generate(response) }
      end

      def escaping_link(path)
        { 'name' => File.basename(path), 'path' => path, 'type' => 'symlink', 'target' => '../../notes.md' }
      end

      def response(paths)
        directories = paths.flat_map { |path| directories_of(path) }.uniq
        listed = directories.map { |path| tree_entry(path, DIRECTORY_MODE, 'tree') } +
                 paths.map { |path| tree_entry(path, file_mode(path), 'blob') } + extras
        { 'sha' => SHA, 'tree' => listed.sort_by { |entry| entry['path'] }, 'truncated' => truncated }
      end

      def file_mode(path)
        symlinked.include?(path) || escaping.include?(path) ? SYMLINK_MODE : FILE_MODE
      end

      # "a/b/c.md" is in "a" and "a/b".
      def directories_of(path)
        parents = path.split('/')[0...-1]
        parents.each_index.map { |index| parents.first(index + 1).join('/') }
      end

      def tree_entry(path, mode, type)
        { 'path' => path, 'mode' => mode, 'type' => type, 'sha' => SHA }
      end
    end
  end
end

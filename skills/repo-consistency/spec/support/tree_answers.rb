# frozen_string_literal: true

require_relative 'script_calls'
require_relative '../../lib/repo_consistency/tier'
require_relative '../../lib/repo_consistency/user_skills'
require_relative '../../lib/repo_consistency/vendored_paths'

module RepoConsistency
  module Testing
    # The answers one repository gives the skill-name check's reads, in the
    # recorded shape: its root tree, then its .claude directory's whole
    # tree, both built from each of its files, their directories and
    # +extras+ (a submodule, say); then the contents read of each
    # instruction file the vendored reads didn't cover, then of each
    # user-level skill's SKILL.md or command file that is a link.
    #
    # +truncated+ names the listing GitHub cuts off, :root or :claude, and
    # +claude_sha+ the id the root gives .claude's tree. A file +symlinked+
    # names is a symlink in the tree whose contents read, as GitHub's does
    # for a target in the repository, gives the target's text; one
    # +escaping+ names, a symlink out of the repository, which the API
    # answers as a symlink. One +oversized+ names is answered as GitHub
    # answers for a file over 1 MB.
    class TreeAnswers
      include ScriptCalls

      FILE_MODE = '100644'
      SYMLINK_MODE = '120000'
      DIRECTORY_MODE = '040000'
      SHA = '0' * 40
      CLAUDE_SHA = 'c' * 40

      attr_accessor :extras, :truncated, :claude_sha, :symlinked, :escaping, :oversized

      def initialize
        @extras = []
        @truncated = nil
        @claude_sha = CLAUDE_SHA
        @symlinked = []
        @escaping = []
        @oversized = []
      end

      # The entries for +repository+ at +branch+, whose files are +files+ by
      # path; none for a personal repository. A spec whose scan stops early,
      # on a truncated tree, a link where it looks or an oversized file, has
      # no file to read after that point, so these needn't know where the
      # reader stops.
      def entries(repository, branch, files)
        return [] if Tier.of(files) == Tier::PERSONAL

        reads = (unread_instruction_files(files.keys) + shipping_links(files.keys)).map do |path|
          entry(contents_call(repository, path, branch), **file_answer(path, files[path]))
        end
        [*tree_entries(repository, branch, files.keys), *reads]
      end

      private

      def tree_entries(repository, branch, paths)
        root = root_listing(paths)
        calls = [entry(tree_call(repository, branch), stdout: JSON.generate(response(root, :root)))]
        claude = root.find { |listed| listed['sha'] == claude_sha }
        return calls if truncated == :root || claude.nil?

        calls << claude_entry(repository, subtree_listing(paths, claude['path']))
      end

      def claude_entry(repository, listed)
        entry(subtree_call(repository, claude_sha), stdout: JSON.generate(response(listed, :claude)))
      end

      def response(listed, listing)
        { 'sha' => SHA, 'tree' => listed.sort_by { |each| each['path'] }, 'truncated' => truncated == listing }
      end

      def root_listing(paths)
        whole(paths).reject { |listed| listed['path'].include?('/') }.map do |listed|
          claude = listed['type'] == 'tree' && listed['path'].casecmp?('.claude')
          claude ? listed.merge('sha' => claude_sha) : listed
        end
      end

      def subtree_listing(paths, claude)
        prefix = "#{claude}/"
        whole(paths).filter_map do |listed|
          listed.merge('path' => listed['path'].delete_prefix(prefix)) if listed['path'].start_with?(prefix)
        end
      end

      # Every entry of the whole tree under its full path.
      def whole(paths)
        directories = (paths + extras.map { |extra| extra['path'] }).flat_map { |path| directories_of(path) }.uniq
        directories.map { |path| tree_entry(path, DIRECTORY_MODE, 'tree') } +
          paths.map { |path| tree_entry(path, file_mode(path), 'blob') } + extras
      end

      def unread_instruction_files(paths)
        instruction_files = paths.select do |path|
          folded = path.downcase
          %w[claude.md .claude/claude.md].include?(folded) ||
            (folded.start_with?('.claude/rules/') && folded.end_with?('.md'))
        end
        (instruction_files - VendoredPaths::ALL).sort
      end

      def shipping_links(paths)
        shipping = UserSkills::NAMES.flat_map do |name|
          [".claude/skills/#{name}/SKILL.md", ".claude/commands/#{name.tr(':', '/')}.md"]
        end
        (shipping & paths).select { |path| file_mode(path) == SYMLINK_MODE }.sort
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

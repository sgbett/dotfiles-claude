# frozen_string_literal: true

require 'digest'
require 'pathname'
require_relative 'git'
require_relative 'porcelain'

module SkillSupport
  # The git checkout a skill's running scripts live in, if they live in one.
  # When it has changes under the skill's own directory or skills/_support,
  # or to the files that pick their Ruby, ignored ones included, or its HEAD
  # isn't in its default branch, the scripts may not be the reviewed ones,
  # so the skill asks first; the yes names a digest of what was there when
  # it was given. It also says whether that checkout is the working
  # directory's, whose branch then mustn't be switched mid-run, as that would
  # swap the scripts.
  class ScriptsCheckout
    SUPPORT_DIRECTORY = '_support'
    # The directory of skills/_support/ that ruby-launch lives and asks mise
    # for the Ruby in.
    LAUNCH_DIRECTORY = 'bin'
    # The config and tool-versions files ruby-launch lets mise read, which
    # makes every other one inert.
    MISE_CONFIG_FILES = %w[mise.toml .mise.toml].freeze
    MISE_TOOL_VERSIONS_FILES = %w[.tool-versions].freeze
    # What mise reads for that Ruby in each directory from there up to the
    # checkout's root: Ruby's own version files, those, and the early-init
    # files whose settings can turn mise away from them. Git may ignore any
    # of them, so ignored ones count as changes too.
    RUBY_FILES = ['.ruby-version', 'Gemfile', *MISE_TOOL_VERSIONS_FILES, *MISE_CONFIG_FILES, '.miserc.toml',
                  '.config/miserc.toml'].freeze
    DEFAULT_BRANCH = 'refs/remotes/origin/HEAD'
    ACCEPT_FLAG = '--accept-scripts'
    # The reason under which each skill's Reasons words the ask.
    REASON = :scripts_unreviewed
    TOKEN = /\A[0-9a-f]{64}\z/
    NOT_A_REPOSITORY = 128

    # +top_level+ is nil when the scripts aren't in a git checkout, such as
    # an installed copy; nothing else is looked at then, and +changes+ is nil
    # too. +token+ is the digest a yes names, set only when the scripts are
    # unreviewed; +ask+ the ask for them, nil once a yes names that digest.
    Inspection = Struct.new(:top_level, :in_work_tree, :changes, :on_default_branch, :token, :accepted, :ask,
                            keyword_init: true) do
      def unreviewed?
        !top_level.nil? && (!changes.empty? || !on_default_branch)
      end
    end

    # +value+, the digest a yes names, as --accept-scripts takes it.
    def self.token!(value)
      return value if value.is_a?(String) && TOKEN.match?(value)

      raise InvalidIdentifier.new(:scripts_digest, value)
    end

    # +skill_directory+ is the running skill's directory, symlinks resolved;
    # +reasons+ the skill's Reasons, whose ask words REASON's question.
    def initialize(runner, skill_directory:, reasons:)
      @git = Git.new(runner)
      @skill_directory = skill_directory
      @reasons = reasons
    end

    # +work_tree+ is the working directory's top level, when whether the
    # scripts live there matters; +accepted+ the token a yes was given for,
    # if any.
    def examine(work_tree: nil, accepted: nil)
      top = top_level
      return Inspection.new(in_work_tree: false, on_default_branch: true, accepted: false) unless top

      status = status(top)
      changes = Porcelain.entries(status).uniq
      on_default_branch = on_default_branch?(top)
      token = token(top, status, changes) unless changes.empty? && on_default_branch
      Inspection.new(top_level: top, in_work_tree: top == work_tree, changes: changes,
                     on_default_branch: on_default_branch, token: token, accepted: !token.nil? && token == accepted,
                     ask: ask(token, accepted))
    end

    private

    def top_level
      result = @git.run('-C', @skill_directory, 'rev-parse', '--show-toplevel', allowed: [0, NOT_A_REPOSITORY])
      File.realpath(result.stdout.chomp) if result.success?
    end

    # The ask for unreviewed scripts, whose digest is +token+, unless the
    # yes given was for that digest.
    def ask(token, accepted)
      @reasons.ask(REASON, accept_with: [ACCEPT_FLAG, token]) unless token.nil? || token == accepted
    end

    # The skill's directory and skills/_support beside it, as the top level
    # sees them; a symlinked _support is checked as the link.
    def directories(top)
      [@skill_directory, support_directory].map { |path| relative(path, top) }
    end

    # The files that pick the Ruby, at the top level, in skills/,
    # skills/_support/ and skills/_support/bin/, where mise starts.
    def ruby_files(top)
      [top, File.dirname(@skill_directory), support_directory, File.join(support_directory, LAUNCH_DIRECTORY)]
        .flat_map { |directory| RUBY_FILES.map { |name| relative(File.join(directory, name), top) } }
    end

    def support_directory
      File.join(File.dirname(@skill_directory), SUPPORT_DIRECTORY)
    end

    def relative(path, top)
      Pathname(path).relative_path_from(Pathname(top)).to_s
    end

    # The changes under the skill's directories, then to the files that pick
    # the Ruby, ignored ones included.
    def status(top)
      porcelain(top, directories(top)) + porcelain(top, ruby_files(top), '--ignored')
    end

    def porcelain(top, pathspecs, *options)
      @git.output('-C', top, *Git::NO_FSMONITOR, '--no-optional-locks', 'status', '--porcelain=v1', '-z',
                  '--untracked-files=all', *options, '--', *pathspecs)
    end

    # Whether HEAD's commit is in the default branch origin names: a commit
    # there has been through review, whichever branch is checked out. With
    # no origin/HEAD to tell, it isn't.
    def on_default_branch?(top)
      default = @git.line_or_nil('-C', top, 'symbolic-ref', '--quiet', DEFAULT_BRANCH)
      !default.nil? && @git.run('-C', top, 'merge-base', '--is-ancestor', 'HEAD', default, allowed: [0, 1]).success?
    end

    # A digest of HEAD and every change status covers, untracked and ignored
    # files' contents included.
    def token(top, status, changes)
      unversioned = changes.select { |change| change.untracked? || change.ignored? }.map(&:path)
      parts = [@git.output('-C', top, 'rev-parse', '--verify', 'HEAD'), status,
               @git.output('-C', top, *Git::NO_FSMONITOR, 'diff', '--binary', '--no-ext-diff', '--no-textconv',
                           'HEAD', '--', *directories(top), *ruby_files(top))]
      parts << @git.output('-C', top, 'hash-object', '--no-filters', '--', *unversioned) unless unversioned.empty?
      Digest::SHA256.hexdigest(parts.join("\0"))
    end
  end
end

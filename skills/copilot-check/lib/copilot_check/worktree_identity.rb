# frozen_string_literal: true

module CopilotCheck
  # Whether the directory a listed worktree's path resolves to holds that
  # worktree still: a checkout of the working directory's repository, by
  # the git directory all its worktrees share, with the listed branch
  # checked out at the listed commit. git lists a worktree from the
  # repository's own records, which a directory replaced at its path, or a
  # link put there to another repository, doesn't change.
  class WorktreeIdentity
    COMMON_DIRECTORY = %w[rev-parse --path-format=absolute --git-common-dir].freeze
    NOT_A_REPOSITORY = 128

    def initialize(runner)
      @git = SkillSupport::Git.new(runner)
    end

    # Whether the checkout at +top_level+, symlinks resolved, is of the
    # working directory's repository, with +branch+ checked out at +head+.
    def confirmed?(top_level, branch, head)
      working_common_directory == common_directory(top_level) &&
        @git.line_or_nil('-C', top_level, 'symbolic-ref', '--quiet', 'HEAD') == "refs/heads/#{branch}" &&
        @git.line_or_nil('-C', top_level, 'rev-parse', '--verify', '--quiet', 'HEAD') == head
    end

    private

    # The working directory's, whose worktrees git listed.
    def working_common_directory
      File.realpath(@git.output(*COMMON_DIRECTORY).chomp)
    end

    # Nil for a directory in no repository.
    def common_directory(top_level)
      result = @git.run('-C', top_level, *COMMON_DIRECTORY, allowed: [0, NOT_A_REPOSITORY])
      File.realpath(result.stdout.chomp) if result.success?
    end
  end
end

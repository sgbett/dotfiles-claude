# frozen_string_literal: true

module CopilotCheck
  # The worktrees of the working directory's repository, the main one and
  # every linked one, as `git worktree list --porcelain -z` gives them: a
  # line for each attribute, its label then any value, and an empty line
  # after each worktree. -z ends each line with a NUL, so that a path can
  # hold any other character.
  class Worktrees
    ARGUMENTS = %w[worktree list --porcelain -z].freeze
    PATH = 'worktree'
    HEAD = 'HEAD'
    BRANCH = 'branch'

    # +path+ is its top level, as git lists it; +head+ its HEAD's commit.
    Worktree = Struct.new(:path, :head, keyword_init: true)

    def initialize(runner)
      @git = SkillSupport::Git.new(runner)
    end

    # The Worktree with branch +branch+ checked out, as git allows in one
    # alone, or nil when none has it.
    def checked_out(branch)
      attributes = listed.find { |worktree| worktree[BRANCH] == "refs/heads/#{branch}" }
      Worktree.new(path: attributes[PATH], head: attributes[HEAD]) if attributes
    end

    private

    # Each worktree's attributes, by label; a label alone, such as
    # detached, has a nil value.
    def listed
      lines = @git.output(*ARGUMENTS).split("\0").reject(&:empty?)
      lines.slice_before { |line| line.start_with?("#{PATH} ") }.map do |worktree|
        worktree.to_h do |line|
          label, value = line.split(' ', 2)
          [label, value]
        end
      end
    end
  end
end

# frozen_string_literal: true

require_relative 'git'
require_relative 'porcelain'

module Do
  # preflight ran outside any git repository: /do works in a checkout, and
  # the gate file lives in one.
  class NotACheckout < SkillSupport::Error
    def initialize
      super('run /do from a checkout of the issue\'s repository, or of a fork of it')
    end
  end

  # The git checkout preflight runs in: the working directory.
  class Checkout
    def initialize(runner)
      @runner = runner
      @git = Git.new(runner)
    end

    # origin's URL as git reports it, after any url.<base>.insteadOf
    # rewriting, or nil when there is no origin.
    def origin_url
      result = @runner.run(%w[git remote get-url origin])
      url = result.stdout.chomp
      url if result.success? && !url.empty?
    end

    # The absolute path of the git directory every worktree of the
    # repository shares.
    def common_directory
      result = @runner.run(%w[git rev-parse --path-format=absolute --git-common-dir])
      directory = result.stdout.chomp
      raise NotACheckout unless result.success? && !directory.empty?

      directory
    end

    # The root of the working tree, symlinks resolved.
    def top_level
      result = @runner.run(%w[git rev-parse --show-toplevel])
      directory = result.stdout.chomp
      raise NotACheckout unless result.success? && !directory.empty?

      File.realpath(directory)
    end

    # The names `git remote` lists.
    def remote_names
      result = @runner.run(%w[git remote])
      raise NotACheckout unless result.success?

      result.stdout.scrub.lines(chomp: true).reject(&:empty?)
    end

    # Every URL a push to +remote+ goes to, its pushurls or else its url, as
    # git rewrites them; empty when it has none, or isn't a remote.
    def push_urls(remote)
      result = @runner.run(['git', 'remote', 'get-url', '--push', '--all', remote])
      result.success? ? result.stdout.scrub.lines(chomp: true).reject(&:empty?) : []
    end

    # Every change in the working tree, untracked files included, as
    # Porcelain entries. --no-optional-locks keeps status from rewriting the
    # index of a checkout it only reads.
    def changes
      Porcelain.entries(@git.output(*Git::NO_FSMONITOR, '--no-optional-locks', 'status', '--porcelain=v1', '-z',
                                    '--untracked-files=all'))
    end
  end
end

# frozen_string_literal: true

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
  end
end

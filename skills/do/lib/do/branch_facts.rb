# frozen_string_literal: true

require_relative 'git'

module Do
  # The push remote's copy of the branch moved between check's ls-remote and
  # its fetch, as a force-push mid-run would make it.
  class BranchMoved < SkillSupport::Error
    def initialize(ref)
      super("the push remote's #{ref} moved while check read it; run check again")
    end
  end

  # The git facts `preflight check` judges an existing branch on, from the
  # working directory's repository and the push remote: the remote's copy,
  # the local copy and its branch.<name>.* configuration, and the local
  # commits the push remote lacks. BranchAssessment makes the decision.
  #
  # The remote's copy is read from the push URLs the remote check passed,
  # never through the remote's name, whose fetch URL can name another
  # repository; its tip is fetched from them too, so the lead can check out
  # that commit. Nor are the commits the user is asked to accept ever
  # measured against remote-tracking refs, which any fetch refspec, such as
  # one for refs/pull/*, can fill.
  class BranchFacts
    MAX_COMMITS = 50
    LOG_FORMAT = '--format=%h %an %s'

    # Tips are full object names, nil for no such branch. +remote_tips+ holds
    # each push URL's, in their order, and +remote_tip+ the one they share,
    # nil when they differ. The configuration values are nil when unset.
    # +lacking+ is the local commits the push remote's copy lacks or, with
    # no copy there, those the base lacks, newest first, at most MAX_COMMITS
    # of them (+more_lacking+ when there are more), as `git log
    # --format='%h %an %s'` prints them; nil when there is no local branch,
    # or the push URLs differ.
    Facts = Struct.new(:remote_tips, :remote_tip, :local_tip, :tracking_remote, :push_remote, :merge, :lacking,
                       :more_lacking, keyword_init: true) do
      def remote_tips_differ?
        remote_tips.to_a.uniq.length > 1
      end
    end

    # +urls+ are the push URLs the remote check passed, as git gave them, and
    # +base_commit+ the commit GitHub gave for the base branch.
    def initialize(runner, urls:, base_commit:)
      @git = Git.new(runner)
      @urls = urls
      @base_commit = base_commit
    end

    # The Facts about the branch named +branch+.
    def collect(branch)
      ref = "refs/heads/#{branch}"
      remote_tips = @urls.map { |url| remote_tip(url, ref) }
      return Facts.new(remote_tips: remote_tips, more_lacking: false) if remote_tips.uniq.length > 1

      remote_tip = remote_tips.first
      fetch(ref, remote_tip) if remote_tip
      local_tip = @git.line_or_nil('rev-parse', '--verify', '--quiet', ref)
      facts = { remote_tips: remote_tips, remote_tip: remote_tip, local_tip: local_tip }
      return Facts.new(**facts, more_lacking: false) unless local_tip

      Facts.new(**facts, **configuration(branch), **lacking(ref, remote_tip))
    end

    private

    # git ls-remote matches a pattern against the tail of a ref's name, so
    # refs/heads/x/<branch> would match <branch>: only the exact ref counts.
    def remote_tip(url, ref)
      @git.output(*Git::NO_HOOKS_OR_FSMONITOR, 'ls-remote', url, ref).lines(chomp: true).each do |line|
        sha, name = line.split("\t", 2)
        return SkillSupport::Identifiers.commit_sha!(sha) if name == ref
      end
      nil
    end

    # Every push URL holds +tip+, so the first serves.
    def fetch(ref, tip)
      return if present?(tip)

      @git.run(*Git::NO_HOOKS_OR_FSMONITOR, 'fetch', '--no-tags', '--quiet', @urls.first, ref)
      raise BranchMoved, ref unless present?(tip)
    end

    # The base commit, for log to measure against, fetched by its name
    # through the first push URL when it isn't here.
    def fetch_base
      return if present?(@base_commit)

      @git.run(*Git::NO_HOOKS_OR_FSMONITOR, 'fetch', '--no-tags', '--quiet', @urls.first, @base_commit)
    end

    def present?(sha)
      !@git.line_or_nil('rev-parse', '--verify', '--quiet', "#{sha}^{commit}").nil?
    end

    def configuration(branch)
      { tracking_remote: config(branch, 'remote'), push_remote: config(branch, 'pushRemote'),
        merge: config(branch, 'merge') }
    end

    def config(branch, key)
      @git.line_or_nil('config', '--get', "branch.#{branch}.#{key}")
    end

    # A branch the push remote doesn't hold lacks every commit the base,
    # as GitHub gave it, doesn't hold.
    def lacking(ref, remote_tip)
      return log("#{remote_tip}..#{ref}") if remote_tip

      fetch_base
      log(ref, '--not', @base_commit)
    end

    # log.showSignature would add signature checks to the lines.
    def log(*revisions)
      lines = @git.output('log', '--no-show-signature', LOG_FORMAT, "--max-count=#{MAX_COMMITS + 1}", *revisions, '--')
                  .lines(chomp: true)
      { lacking: lines.first(MAX_COMMITS), more_lacking: lines.length > MAX_COMMITS }
    end
  end
end

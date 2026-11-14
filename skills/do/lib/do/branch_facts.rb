# frozen_string_literal: true

require_relative 'git'
require_relative 'remote_tips'

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
  # The remote's branches are read from the push URLs the remote check
  # passed, never through the remote's name, whose fetch URL can name another
  # repository; the branch's tip is fetched from them too, so the lead can
  # check out that commit. The commits the user is asked to accept are
  # measured against those branches and the base alone, never against
  # remote-tracking refs, which any fetch refspec, such as one for
  # refs/pull/*, can fill.
  class BranchFacts
    MAX_COMMITS = 50
    LOG_FORMAT = '--format=%h %an %s'
    UNLISTED = { lacking: nil, more_lacking: false, lacking_approximate: false }.freeze

    # Tips are full object names, nil for no such branch. +remote_tips+ holds
    # each push URL's, in their order, and +remote_tip+ the one they share,
    # nil when they differ. The configuration values are nil when unset.
    # +lacking+ is the local commits the push remote's copy lacks or, with
    # no copy there, those neither the base nor any branch on every push URL
    # holds, newest first, at most MAX_COMMITS of them (+more_lacking+ when
    # there are more), as `git log --format='%h %an %s'` prints them; nil
    # when there is no local branch, or the push URLs differ.
    # +lacking_approximate+ when some branch's tip couldn't be measured
    # against, so the list may hold commits the push remote has.
    Facts = Struct.new(:remote_tips, :remote_tip, :local_tip, :tracking_remote, :push_remote, :merge, :lacking,
                       :more_lacking, :lacking_approximate, keyword_init: true) do
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
      branches = remote_branches
      remote_tips = branches.map { |advertised| advertised[ref] }
      return Facts.new(remote_tips: remote_tips, **UNLISTED) if remote_tips.uniq.length > 1

      remote_tip = remote_tips.first
      fetch(ref, remote_tip) if remote_tip
      local_tip = @git.line_or_nil('rev-parse', '--verify', '--quiet', ref)
      facts = { remote_tips: remote_tips, remote_tip: remote_tip, local_tip: local_tip }
      return Facts.new(**facts, **UNLISTED) unless local_tip

      Facts.new(**facts, **configuration(branch), **lacking(ref, remote_tip, branches))
    end

    private

    # For each push URL, in their order, each branch it advertises, by its
    # full name, at its tip: refs/heads/* alone, never refs/pull/*. --heads
    # rather than --branches, which git before 2.46 lacks.
    def remote_branches
      @urls.map do |url|
        @git.output(*Git::NO_HOOKS_OR_FSMONITOR, 'ls-remote', '--heads', url).lines(chomp: true).to_h do |line|
          sha, name = line.split("\t", 2)
          [name, SkillSupport::Identifiers.commit_sha!(sha)]
        end
      end
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

    # A branch the push remote doesn't hold lacks every commit that neither
    # the base, as GitHub gave it, nor a branch tip every push URL
    # advertises holds, as a push goes to every URL. A tip left unmeasured,
    # one only some URLs advertise or one that isn't here, leaves its
    # commits listed: the list is then approximate, never short.
    def lacking(ref, remote_tip, branches)
      return { **log("#{remote_tip}..#{ref}"), lacking_approximate: false } if remote_tip

      fetch_base
      tips = branches.map { |advertised| advertised.values.uniq }
      measured = RemoteTips.new(@git, url: @urls.first).here(tips.reduce(:&))
      { **log(ref, '--not', @base_commit, excluded: measured), lacking_approximate: !(tips.flatten - measured).empty? }
    end

    # log.showSignature would add signature checks to the lines. The
    # +excluded+ commits go on standard input, as a remote can have more
    # branches than a command line holds.
    def log(*revisions, excluded: nil)
      stdin = excluded&.map { |commit| "^#{commit}\n" }&.join
      lines = @git.output('log', '--no-show-signature', LOG_FORMAT, "--max-count=#{MAX_COMMITS + 1}",
                          *('--stdin' if stdin), *revisions, '--', stdin: stdin).lines(chomp: true)
      { lacking: lines.first(MAX_COMMITS), more_lacking: lines.length > MAX_COMMITS }
    end
  end
end

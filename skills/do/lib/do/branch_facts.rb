# frozen_string_literal: true

require_relative 'git'

module Do
  # The git facts pre-flight step 2 judges an existing branch on, from the
  # working directory's repository and the push remote: the remote's copy,
  # the local copy and its branch.<name>.* configuration, and the local
  # commits the push remote lacks. BranchAssessment makes the decision.
  class BranchFacts
    MAX_COMMITS = 50
    LOG_FORMAT = '--format=%h %an %s'

    # Tips are full object names, nil for no such branch. The configuration
    # values are nil when unset. +lacking+ is the local commits the push
    # remote lacks, newest first, at most MAX_COMMITS of them (+more_lacking+
    # when there are more), as `git log --format='%h %an %s'` prints them;
    # nil when there is no local branch, or the remote's tip couldn't be
    # fetched to compare with.
    Facts = Struct.new(:remote_tip, :local_tip, :tracking_remote, :push_remote, :merge, :lacking, :more_lacking,
                       keyword_init: true)

    # +remote+ is the push remote's name.
    def initialize(runner, remote:)
      @git = Git.new(runner)
      @remote = remote
    end

    # The Facts about the branch named +branch+.
    def collect(branch)
      ref = "refs/heads/#{branch}"
      remote_tip = remote_tip(ref)
      local_tip = @git.line_or_nil('rev-parse', '--verify', '--quiet', ref)
      return Facts.new(remote_tip: remote_tip, more_lacking: false) unless local_tip

      Facts.new(remote_tip: remote_tip, local_tip: local_tip, **configuration(branch), **lacking(ref, remote_tip))
    end

    private

    # git ls-remote matches a pattern against the tail of a ref's name, so
    # refs/heads/x/<branch> would match <branch>: only the exact ref counts.
    def remote_tip(ref)
      @git.output('ls-remote', @remote, ref).lines(chomp: true).each do |line|
        sha, name = line.split("\t", 2)
        return SkillSupport::Identifiers.commit_sha!(sha) if name == ref
      end
      nil
    end

    def configuration(branch)
      { tracking_remote: config(branch, 'remote'), push_remote: config(branch, 'pushRemote'),
        merge: config(branch, 'merge') }
    end

    def config(branch, key)
      @git.line_or_nil('config', '--get', "branch.#{branch}.#{key}")
    end

    # A branch never pushed lacks every commit no remote-tracking branch of
    # the push remote has.
    def lacking(ref, remote_tip)
      return log(ref, '--not', "--remotes=#{@remote}") unless remote_tip
      return { lacking: nil, more_lacking: false } unless fetched?(ref, remote_tip)

      log("#{remote_tip}..#{ref}")
    end

    def fetched?(ref, remote_tip)
      return true if present?(remote_tip)

      @git.run('fetch', '--no-tags', '--quiet', @remote, ref)
      present?(remote_tip)
    end

    def present?(sha)
      !@git.line_or_nil('rev-parse', '--verify', '--quiet', "#{sha}^{commit}").nil?
    end

    # log.showSignature would add signature checks to the lines.
    def log(*revisions)
      lines = @git.output('log', '--no-show-signature', LOG_FORMAT, "--max-count=#{MAX_COMMITS + 1}", *revisions, '--')
                  .lines(chomp: true)
      { lacking: lines.first(MAX_COMMITS), more_lacking: lines.length > MAX_COMMITS }
    end
  end
end

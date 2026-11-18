# vendored from sgbett/dotfiles-claude profiles/git-workflow/hooks/push-guard.rb
# frozen_string_literal: true

# The deciding half of the push-guard PreToolUse hook; the sh entry beside it
# runs this only for a Bash command that mentions push, on a machine with ruby.
#
# It runs under whatever ruby a collaborator has, macOS's 2.6 included, so it
# uses the standard library alone and only syntax that 2.6 parses.
#
# It never answers allow: that would silence the ask rules a user has set and
# ship a grant into every checkout that vendors it. Anything it cannot settle,
# an exception included, becomes ask, so a defect cannot fail open.

require 'json'
require 'open3'
require 'shellwords'

module PushGuard
  # Never rewritten or deleted. Matched with FNM_PATHNAME off, so project/x/y
  # matches project/* too.
  BASE_BRANCHES = ['master', 'project/*', 'releases/*'].freeze

  # Every reason the hook can give, so the texts live in one place.
  module Reasons
    BARE_FORCE = 'push-guard: a bare force-push rewrites whatever is on the remote; ' \
                 'use git push --force-with-lease --force-if-includes on your own branch'
    EVERY_BRANCH = 'push-guard: --all with a lease may rewrite every branch, base branches included. Push anyway?'
    UNBALANCED_QUOTES = "push-guard: the command's quotes do not balance, so the push in it could not be read"

    def self.base_branch(branch)
      "push-guard: #{branch} is a base branch; it is never rewritten or deleted"
    end

    def self.other_authors(branch, remote, count)
      "push-guard: #{branch} on #{remote} has commits by #{count} other author(s); " \
        'a branch with another active committer is theirs until they say otherwise. Push anyway?'
    end

    def self.unreadable(construct)
      "push-guard: a push behind #{construct} cannot be read; run git push on its own command line"
    end

    def self.unknown_git_option(option)
      "push-guard: the git option #{option} is not understood, so the push could not be checked"
    end

    def self.failure(error)
      "push-guard: #{error.class}: #{error.message}"
    end
  end

  # What the hook answers: deny or ask with a reason, never allow. Across a
  # command the strictest answer stands.
  class Decision
    RANK = { 'deny' => 2, 'ask' => 1 }.freeze

    attr_reader :kind, :reason

    def self.deny(reason)
      new('deny', reason)
    end

    def self.ask(reason)
      new('ask', reason)
    end

    def self.strictest(decisions)
      decisions.compact.max_by { |decision| RANK.fetch(decision.kind) }
    end

    def initialize(kind, reason)
      @kind = kind
      @reason = reason
    end

    def to_json(*)
      JSON.generate('hookSpecificOutput' => { 'hookEventName' => 'PreToolUse', 'permissionDecision' => kind,
                                              'permissionDecisionReason' => reason })
    end
  end

  # One refspec of a push: +src:dst, src:dst, :dst or src.
  class Refspec
    attr_reader :destination

    def initialize(text)
      @force = text.start_with?('+')
      source, destination = text.sub(/\A\+/, '').split(':', 2)
      @deletion = source.to_s.empty? && !destination.nil?
      @destination = (destination || source).to_s.sub(%r{\Arefs/heads/}, '')
    end

    def force?
      @force
    end

    def deletion?
      @deletion
    end

    # A bare HEAD pushes to the branch named as the current one.
    def current_branch?
      destination == 'HEAD'
    end
  end

  # A git push as its arguments describe it: the force forms, the remote and
  # the refspecs, and the directory the command runs in.
  class Push
    WITH_ARGUMENT = %w[-o --push-option --repo --receive-pack --exec].freeze
    SHORT_BUNDLE = /\A-[A-Za-z]+\z/

    attr_reader :remote, :refspecs, :lease_ref, :directory

    def initialize(arguments, directory)
      @directory = directory
      @force = @lease = @mirror = @delete = @all = false
      @lease_ref = nil
      positionals = read(arguments)
      @remote = positionals.first
      @refspecs = positionals.drop(1).map { |text| Refspec.new(text) }
    end

    # --mirror, --force or -f without a lease, or a + refspec: nothing checks
    # what the remote holds before it is overwritten.
    def bare_force?
      @mirror || (@force && !@lease) || refspecs.any?(&:force?)
    end

    # The remote's refs are force-updated or removed, not merely advanced.
    def rewrites?
      @force || @lease || @delete
    end

    def lease?
      @lease
    end

    def all?
      @all
    end

    private

    def read(arguments)
      positionals = []
      rest = arguments.dup
      while (word = rest.shift)
        if word == '--'
          positionals.concat(rest)
          break
        end
        word.start_with?('-') ? option(word, rest) : positionals << word
      end
      positionals
    end

    def option(word, rest)
      case word
      when '--force' then @force = true
      when '--force-with-lease' then @lease = true
      when /\A--force-with-lease=([^:]*)/ then lease_on(Regexp.last_match(1))
      when '--mirror' then @mirror = true
      when '--delete' then @delete = true
      when '--all', '--branches' then @all = true
      when *WITH_ARGUMENT then rest.shift
      when SHORT_BUNDLE then short_options(word, rest)
      end
    end

    def lease_on(ref)
      @lease = true
      @lease_ref = ref.sub(%r{\Arefs/heads/}, '') unless ref.empty?
    end

    # Letters bundled after one dash, as in -fu: f forces, d deletes, and a
    # trailing o takes the next word as its push option.
    def short_options(word, rest)
      letters = word[1..]
      @force = true if letters.include?('f')
      @delete = true if letters.include?('d')
      rest.shift if letters.end_with?('o')
    end
  end

  # One simple command of the Bash text, read from its command word: what
  # precedes it without changing it (shell keywords, wrappers, NAME=value
  # assignments) and redirections are dropped first.
  class Segment
    PREFIX_WORDS = %w[command env exec nice time if then else elif while until do { !].freeze
    ASSIGNMENT = /\A[A-Za-z_][A-Za-z0-9_]*=/
    # `>`, `2>`, `>>`, `<` or `&>` on its own: the next word is the file.
    REDIRECTION_OPERATOR = /\A(?:\d*>>?|\d*<|&>)\z/
    # `2>&1`, `>/dev/null`, `&>file`, or a trailing `&`.
    REDIRECTION = /\A(?:\d*[<>]|&)/

    attr_reader :words

    def initialize(words)
      @words = without_prefix(without_redirections(words))
    end

    def change_directory?
      words.first == 'cd'
    end

    # Where a cd goes: ~ for a bare cd, nil for a form (cd -, options) the
    # hook does not follow.
    def change_directory_target
      return '~' if words.length == 1
      return if words.length > 2 || words[1].start_with?('-')

      words[1]
    end

    def git?
      !words.empty? && File.basename(words.first) == 'git'
    end

    def git_arguments
      words.drop(1)
    end

    private

    def without_prefix(words)
      words.drop_while { |word| PREFIX_WORDS.include?(word) || ASSIGNMENT.match?(word) }
    end

    def without_redirections(words)
      kept = []
      skip_next = false
      words.each do |word|
        if skip_next
          skip_next = false
        elsif REDIRECTION_OPERATOR.match?(word)
          skip_next = true
        elsif !REDIRECTION.match?(word)
          kept << word
        end
      end
      kept
    end
  end

  # git's own options before the subcommand; -C names the directory, and an
  # option the hook does not know ends the reading.
  class GitCommand
    FLAGS = %w[--no-pager -p --paginate -P --no-replace-objects --bare --literal-pathspecs --glob-pathspecs
               --noglob-pathspecs --icase-pathspecs --no-optional-locks --no-lazy-fetch].freeze
    WITH_ARGUMENT = %w[-c --git-dir --work-tree --namespace --exec-path].freeze
    INLINE_ARGUMENT = /\A--(?:git-dir|work-tree|namespace|exec-path|config-env|super-prefix)=/

    attr_reader :directory, :subcommand, :arguments, :unknown_option

    def initialize(arguments)
      @arguments = arguments.dup
      read_options
    end

    def push?
      subcommand == 'push'
    end

    private

    def read_options
      while (word = @arguments.first) && word.start_with?('-')
        @arguments.shift
        next if known_option?(word)

        @unknown_option = word
        return
      end
      @subcommand = @arguments.shift
    end

    def known_option?(word)
      if word == '-C'
        @directory = @arguments.shift
      elsif WITH_ARGUMENT.include?(word)
        @arguments.shift
      else
        return FLAGS.include?(word) || INLINE_ARGUMENT.match?(word)
      end
      true
    end
  end

  # Reads the Bash text into the pushes it holds, following cd between
  # commands, and into asks for what it cannot read.
  class CommandReader
    SEPARATORS = /\n|;|&&|\|\||\|/
    # Behind these the text no longer says what runs.
    OPAQUE = [/`/, /\$\(/, /\beval\b/, /\bxargs\b/, /\b(?:ba|z)?sh\s+-c\b/].freeze

    attr_reader :pushes, :decisions

    def initialize(command, cwd)
      @command = command
      @cwd = cwd
      @pushes = []
      @decisions = []
    end

    def read
      construct = OPAQUE.map { |pattern| @command[pattern] }.compact.first
      if construct
        ask(Reasons.unreadable(construct)) if @command.include?('git') && @command.include?('push')
      else
        @command.split(SEPARATORS).each { |text| read_segment(text) }
      end
      self
    end

    private

    def ask(reason)
      @decisions << Decision.ask(reason)
    end

    def read_segment(text)
      words = split(text)
      return ask(Reasons::UNBALANCED_QUOTES) if words.nil? && text.include?('push')
      return if words.nil?

      segment = Segment.new(words)
      return follow(segment) if segment.change_directory?
      return unless segment.git?

      read_git(GitCommand.new(segment.git_arguments), text)
    end

    def read_git(git, text)
      if git.unknown_option
        ask(Reasons.unknown_git_option(git.unknown_option)) if text.include?('push')
      elsif git.push?
        @pushes << Push.new(git.arguments, File.expand_path(git.directory || '.', @cwd))
      end
    end

    def follow(segment)
      target = segment.change_directory_target
      @cwd = File.expand_path(target, @cwd) if target
    end

    def split(text)
      Shellwords.split(text)
    rescue ArgumentError
      nil
    end
  end

  # Read-only questions to git in one directory; nil where git has no answer.
  class Repository
    ENVIRONMENT = { 'GIT_OPTIONAL_LOCKS' => '0' }.freeze

    def initialize(directory)
      @directory = directory
    end

    def current_branch
      git('symbolic-ref', '--short', 'HEAD')
    end

    def default_branch(remote)
      head = git('symbolic-ref', '--short', "refs/remotes/#{remote}/HEAD")
      head&.delete_prefix("#{remote}/")
    end

    def ref?(name)
      !git('rev-parse', '--verify', '--quiet', name).nil?
    end

    def config(key)
      git('config', key)
    end

    # [email, name] per commit in +range+.
    def authors(range)
      output = git('log', '--format=%ae%x00%an', range)
      return if output.nil?

      output.lines.map do |line|
        email, name = line.chomp.split("\0", 2)
        [email.to_s, name.to_s]
      end
    end

    private

    def git(*arguments)
      stdout, _stderr, status = Open3.capture3(ENVIRONMENT, 'git', '-c', 'core.fsmonitor=false', *arguments,
                                               chdir: @directory)
      status.success? ? stdout.chomp : nil
    end
  end

  # How many people other than the pusher have commits on the remote's copy
  # of the branch beyond its base; nil when git cannot say.
  class AuthorCheck
    BOT_NAME = /\[bot\]\z/i
    GITHUB_ACTIONS = /github-actions/i

    def initialize(repository, remote, branch)
      @repository = repository
      @remote = remote
      @branch = branch
    end

    def other_authors
      return unless repository.ref?(tracking_ref)

      authors = repository.authors("#{base_ref}..#{tracking_ref}")
      return if authors.nil?

      strangers(authors).map { |email, _name| email.downcase }.uniq.length
    end

    private

    attr_reader :repository, :remote, :branch

    def tracking_ref
      "refs/remotes/#{remote}/#{branch}"
    end

    def base_ref
      "refs/remotes/#{remote}/#{repository.default_branch(remote) || 'master'}"
    end

    def strangers(authors)
      own_email = repository.config('user.email')
      own_name = repository.config('user.name')
      authors.reject { |email, name| same?(own_email, email) || same?(own_name, name) || bot?(email, name) }
    end

    def same?(mine, theirs)
      !mine.nil? && !mine.empty? && mine.casecmp?(theirs)
    end

    def bot?(email, name)
      BOT_NAME.match?(name) || GITHUB_ACTIONS.match?(name) || GITHUB_ACTIONS.match?(email)
    end
  end

  # The decision table for one push, first match wins: a bare force is
  # denied, a rewrite or deletion of a base branch is denied, a lease onto
  # another author's commits is asked about, and the rest is left to the
  # permission rules.
  class Judge
    def initialize(push, repository = Repository.new(push.directory))
      @push = push
      @repository = repository
    end

    def decide
      return Decision.deny(Reasons::BARE_FORCE) if push.bare_force?
      return unless push.rewrites? || push.refspecs.any?(&:deletion?)
      return Decision.ask(Reasons::EVERY_BRANCH) if push.all? && push.lease?

      Decision.strictest(targets.map { |branch, deleting| decide_target(branch, deleting) })
    end

    private

    attr_reader :push, :repository

    def decide_target(branch, deleting)
      return if branch.nil?
      return Decision.deny(Reasons.base_branch(branch)) if base?(branch) && (deleting || push.rewrites?)
      return unless push.lease?

      other_authors_ask(branch)
    end

    def base?(branch)
      BASE_BRANCHES.any? { |pattern| File.fnmatch(pattern, branch) }
    end

    # [branch, deleting] per refspec; without one, the lease's ref, else the
    # current branch.
    def targets
      return push.refspecs.map { |refspec| [branch_of(refspec), refspec.deletion?] } unless push.refspecs.empty?

      [[push.lease_ref || repository.current_branch, false]]
    end

    def branch_of(refspec)
      refspec.current_branch? ? repository.current_branch : refspec.destination
    end

    def other_authors_ask(branch)
      remote = push.remote || 'origin'
      count = AuthorCheck.new(repository, remote, branch).other_authors
      return if count.nil? || count.zero?

      Decision.ask(Reasons.other_authors(branch, remote, count))
    end
  end

  # The entry: one event in, at most one decision out, and a failure is an ask.
  class Hook
    def self.run(input, output)
      decision = new(input.read).decision
      output.puts(decision.to_json) if decision
    rescue StandardError => e
      output.puts(Decision.ask(Reasons.failure(e)).to_json)
    end

    def initialize(event_json)
      @event_json = event_json
    end

    def decision
      event = bash_event
      return unless event

      reader = CommandReader.new(event['command'], event['cwd']).read
      Decision.strictest(reader.decisions + reader.pushes.map { |push| Judge.new(push).decide })
    end

    private

    # The Bash command and its directory, or nil for anything else: the sh
    # entry hands over any stdin that says push.
    def bash_event
      event = JSON.parse(@event_json)
      return unless event.is_a?(Hash) && event['tool_name'] == 'Bash' && event['tool_input'].is_a?(Hash)

      command = event['tool_input']['command']
      return unless command.is_a?(String)

      { 'command' => command, 'cwd' => event['cwd'].is_a?(String) ? event['cwd'] : Dir.pwd }
    rescue JSON::ParserError
      nil
    end
  end
end

PushGuard::Hook.run($stdin, $stdout)

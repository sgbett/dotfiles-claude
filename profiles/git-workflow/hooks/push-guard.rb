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
  # Never rewritten or deleted. A project's pull-request branches live under
  # project/<id>/ beside its base, project/<id>/master, so a * stands for one
  # path segment and not for the rest of the name.
  BASE_BRANCHES = ['master', 'project/*/master', 'releases/*'].freeze
  # A destination may name a branch as refs/heads/x, heads/x or x.
  BRANCH_PREFIX = %r{\A(?:refs/)?heads/}.freeze

  # The directory a command runs in, as far as the hook can follow it.
  module Directory
    # Where a cd or -C lands from +from+, which is nil once the hook has lost
    # track: a relative path then stays lost, an absolute path or ~ recovers.
    def self.follow(from, path)
      return if from.nil? && !path.start_with?('/', '~')

      File.expand_path(path, from)
    end
  end

  # Every reason the hook can give, so the texts live in one place. An ask
  # ends with what silences it.
  module Reasons
    BARE_FORCE = 'push-guard: a bare force-push rewrites whatever is on the remote; ' \
                 'use git push --force-with-lease --force-if-includes on your own branch'
    UNBALANCED_QUOTES = "push-guard: the command's quotes do not balance, so the push in it could not be read"
    UNREADABLE_INPUT = 'push-guard: the hook input could not be read'
    VARIABLE = 'push-guard: a push with an unexpanded $ cannot be read; write the remote and refspec out'
    UNKNOWN_DIRECTORY = 'push-guard: the directory the push runs in could not be followed, so the push could not ' \
                        'be checked; write it as git -C <path> push'
    NO_EMAIL = 'push-guard: user.email is not set, so the commits on the remote could not be told from your own ' \
               'and the push could not be checked; set it with git config user.email <address>'
    UNRESOLVED_DESTINATION = 'push-guard: where a push with no refspec goes could not be resolved, so the push ' \
                             'could not be checked; name the remote and branch, as git push <remote> <branch>'
    BY_NAME = 'git push <remote> <branch>'
    ADDRESS_LENGTH = 64
    ADDRESSES_LISTED = 5

    def self.base_branch(branch)
      "push-guard: #{branch} is a base branch; it is never rewritten or deleted"
    end

    # --all, --prune, a wildcard or matching refspec, push.default=matching
    # and a configured remote.<name>.push: the remote's refs decide what is
    # touched, and the hook cannot see them.
    def self.every_branch(form, by_name = BY_NAME)
      "push-guard: #{form} may rewrite or delete any branch on the remote, base branches included, " \
        "so the targets could not be checked; name them, as #{by_name}. Push anyway?"
    end

    def self.prune
      every_branch('--prune', 'git push <remote> --delete <branch>')
    end

    def self.other_authors(branch, remote, addresses)
      "push-guard: #{branch} on #{remote} has commits by #{addresses.length} other author(s), " \
        "#{address_list(addresses)}; a branch with another active committer is theirs until they say otherwise, " \
        'and an address of your own belongs in .mailmap. Push anyway?'
    end

    # An address is whatever the commit says it is, and the text reaches the
    # permission prompt: only printable characters go in, less the format
    # characters Ruby counts among them (a direction override, a zero-width
    # space), each address is cut to ADDRESS_LENGTH and at most
    # ADDRESSES_LISTED are named.
    def self.address_list(addresses)
      shown = addresses.first(ADDRESSES_LISTED).map do |address|
        address.gsub(/[^[:print:]]|\p{Cf}/, '')[0, ADDRESS_LENGTH]
      end
      rest = addresses.length - shown.length
      rest.positive? ? "#{shown.join(', ')} and #{rest} more" : shown.join(', ')
    end

    def self.unreadable_history(branch, remote, mend)
      "push-guard: the commits of #{branch} on #{remote} beyond its base could not be read, " \
        "so the push could not be checked; run #{mend} first"
    end

    def self.long_history(branch, remote, bound, range)
      "push-guard: #{branch} on #{remote} has #{bound} or more commits beyond its base, more than the hook reads, " \
        "so the push could not be checked; git shortlog -sne #{range} lists their authors"
    end

    def self.unreadable(construct)
      "push-guard: a push behind #{construct} cannot be read; " \
        'run git push on its own command line with the remote and refspec written out'
    end

    def self.filled_tracking_ref(remote, ref)
      "push-guard: remote.#{remote}.fetch fills #{ref} from something other than the branch of that name, so what " \
        'the push would rewrite could not be read and the push could not be checked; name the remote and branch, ' \
        "as git push #{remote} <branch>, from a clone fetching under the default layout, " \
        "+refs/heads/*:refs/remotes/#{remote}/*"
    end

    def self.remapped_fetch(remote)
      "push-guard: remote.#{remote}.fetch does not keep the remote's branches under refs/remotes/#{remote}/ by " \
        'name, so what the push would rewrite could not be read and the push could not be checked; name the remote ' \
        "and branch, as git push #{remote} <branch>, from a clone fetching under the default layout, " \
        "+refs/heads/*:refs/remotes/#{remote}/*"
    end

    def self.prefix_option(option)
      "push-guard: the option #{option} before the command is not understood, so the push could not be checked"
    end

    def self.unknown_git_option(option)
      "push-guard: the git option #{option} is not understood, so the push could not be checked"
    end

    def self.unknown_push_option(option)
      "push-guard: the push option #{option} is not understood, so the push could not be checked"
    end

    def self.config_override(key)
      "push-guard: setting #{key} on the command line changes what push does, so the push could not be checked"
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

    def deny?
      kind == 'deny'
    end

    def to_json(*)
      JSON.generate('hookSpecificOutput' => { 'hookEventName' => 'PreToolUse', 'permissionDecision' => kind,
                                              'permissionDecisionReason' => reason })
    end
  end

  # One refspec of a push: +src:dst, src:dst, :dst, src, or the matching
  # form, a bare colon.
  class Refspec
    attr_reader :text, :destination

    def initialize(text)
      @text = text
      @force = text.start_with?('+')
      source, destination = text.sub(/\A\+/, '').split(':', 2)
      @matching = source.to_s.empty? && destination.to_s.empty?
      @deletion = source.to_s.empty? && !destination.nil? && !@matching
      @destination = (destination || source).to_s.sub(BRANCH_PREFIX, '')
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

    # The colon alone pushes every branch that has a namesake on the remote.
    def matching?
      @matching
    end

    # A * in the destination names whatever the remote's refs match.
    def wildcard?
      destination.include?('*')
    end

    # A destination the hook reads without asking git.
    def named?
      !current_branch? && !matching? && !wildcard?
    end
  end

  # A git push as its arguments describe it: the force forms, the remote and
  # the refspecs, and the directory the command runs in. git accepts any
  # unambiguous abbreviation of a long option, so a long option that is not
  # known here is not understood rather than ignored.
  class Push
    FLAGS = %w[--verbose --quiet --tags --no-tags --dry-run --porcelain --thin --no-thin --set-upstream --progress
               --no-progress --verify --no-verify --follow-tags --no-follow-tags --atomic --no-atomic --ipv4 --ipv6
               --signed --no-signed --recurse-submodules --no-recurse-submodules --force-if-includes
               --no-force-if-includes].freeze
    WITH_ARGUMENT = %w[-o --push-option --receive-pack --exec].freeze
    WITH_INLINE_ARGUMENT = /\A--(?:push-option|receive-pack|exec|recurse-submodules|signed)=/.freeze
    REPO = /\A--repo(?:=|\z)/.freeze
    # --m onwards is unambiguous: no other push option starts with m.
    MIRROR_FORMS = (3..8).map { |length| '--mirror'[0, length] }.freeze
    SHORT_BUNDLE = /\A-[A-Za-z46]+\z/.freeze

    attr_reader :remote, :refspecs, :directory, :unknown_option

    def initialize(arguments, directory)
      @directory = directory
      @force = @lease = @lease_value = @mirror = @delete = @all = @prune = false
      @repo = @unknown_option = nil
      positionals = read(arguments)
      # A positional repository wins over --repo, as git ranks them.
      @remote = positionals.first || @repo
      @refspecs = positionals.drop(1).map { |text| Refspec.new(text) }
    end

    # --mirror, --force or -f, or a + refspec: nothing checks what the remote
    # holds before it is overwritten. A lease beside --force does not help,
    # since --force overrides a stale lease.
    def bare_force?
      @mirror || @force || refspecs.any?(&:force?)
    end

    # The remote's refs are force-updated or removed, not merely advanced.
    def rewrites?
      @force || @lease || @delete
    end

    # Something on the remote may be rewritten or removed, so the targets
    # matter; a plain push never needs git asked anything.
    def destructive?
      rewrites? || prune? || refspecs.any?(&:deletion?)
    end

    def lease?
      @lease
    end

    # --force-with-lease=<ref>:<value> says what the remote must hold, so
    # it rewrites without a remote-tracking ref.
    def lease_value?
      @lease_value
    end

    def deletes?
      @delete
    end

    def all?
      @all
    end

    def prune?
      @prune
    end

    private

    def read(arguments)
      positionals = []
      rest = arguments.dup
      while (word = rest.shift)
        break positionals.concat(rest) if word == '--'

        word.start_with?('-') ? option(word, rest) : positionals << word
      end
      positionals
    end

    def option(word, rest)
      return rest.shift if WITH_ARGUMENT.include?(word)
      return short_options(word, rest) if SHORT_BUNDLE.match?(word)
      return repo_option(word, rest) if REPO.match?(word)
      return if FLAGS.include?(word) || WITH_INLINE_ARGUMENT.match?(word)

      shape_option(word)
    end

    def repo_option(word, rest)
      @repo = word.include?('=') ? word.split('=', 2).last : rest.shift
    end

    # The options that change what the push sends and where.
    def shape_option(word)
      case word
      when *MIRROR_FORMS then @mirror = true
      when '--delete' then @delete = true
      when '--all', '--branches' then @all = true
      when '--prune', '--no-prune' then @prune = word == '--prune'
      else force_option(word)
      end
    end

    def force_option(word)
      case word
      when '--force' then @force = true
      when '--force-with-lease' then @lease = true
      when /\A--force-with-lease=[^:]*(:.*)?\z/ then lease_on(Regexp.last_match(1))
      when '--no-force-with-lease' then @lease = @lease_value = false
      else @unknown_option = word if @unknown_option.nil?
      end
    end

    # --force-with-lease=<ref> expects something of <ref> and pushes nothing
    # more for it: the push goes where it would without the lease.
    def lease_on(value)
      @lease = true
      @lease_value = true unless value.nil?
    end

    # Letters bundled after one dash, as in -fu: f forces, d deletes, and o
    # takes the rest of the bundle as its push option, or the next word when
    # nothing follows it, as git reads -ofoo and -o foo.
    def short_options(word, rest)
      letters, value = word[1..].split('o', 2)
      @force = true if letters.include?('f')
      @delete = true if letters.include?('d')
      rest.shift if value == ''
    end
  end

  # One simple command of the Bash text, read from its command word: what
  # precedes it without changing it (shell keywords, wrappers, NAME=value
  # assignments) and redirections are dropped first, though an assignment
  # that moves git's repository or sets its configuration is kept in mind.
  # An option after a wrapper is not understood, since it may change what
  # runs.
  class Segment
    PREFIX_WORDS = %w[command env exec nice time sudo doas if then else elif while until do { !].freeze
    ASSIGNMENT = /\A[A-Za-z_][A-Za-z0-9_]*=/.freeze
    CHANGE_DIRECTORY = %w[cd pushd popd].freeze
    # GIT_DIR and GIT_WORK_TREE point git at a repository -C does not name.
    DIRECTORY_ASSIGNMENT = /\AGIT_(?:DIR|WORK_TREE)=/.freeze
    # GIT_CONFIG_PARAMETERS, GIT_CONFIG_COUNT with its KEY and VALUE pairs,
    # and GIT_CONFIG_GLOBAL or _SYSTEM set configuration the hook does not
    # see; HOME and XDG_CONFIG_HOME move the global configuration just as
    # GIT_CONFIG_GLOBAL does.
    CONFIG_ASSIGNMENT = /\A(?:GIT_CONFIG_[A-Z0-9_]+|HOME|XDG_CONFIG_HOME)=/.freeze
    # An operator on its own (`>`, `2>`, `>>`, `<`, `<<`, `<<-`, `&>`, `&>>`,
    # `>&`, `<&` or `2>&`): the next word is its file, descriptor or
    # here-document delimiter.
    REDIRECTION_OPERATOR = /\A(?:\d*>>?|\d*<<?-?|&>>?|\d*[<>]&)\z/.freeze
    # An operator with its file or descriptor attached: `2>&1`, `>&2`,
    # `>/dev/null`, `&>file` or `&>>log`.
    REDIRECTION = /\A(?:\d*[<>]|&)/.freeze

    attr_reader :words

    def initialize(words)
      command = without_redirections(words)
      prefix = command.take_while { |word| PREFIX_WORDS.include?(word) || ASSIGNMENT.match?(word) }
      @assignments = prefix.grep(ASSIGNMENT)
      @words = command.drop(prefix.length)
    end

    # The option that follows a wrapper, as in env -i or nice -n 10.
    def prefix_option
      words.first if words.first.to_s.start_with?('-')
    end

    def change_directory?
      CHANGE_DIRECTORY.include?(words.first)
    end

    # Where a cd goes: ~ for a bare cd, and nil for a form the hook cannot
    # follow (cd -, an option, a $, two arguments, pushd, popd), after which
    # the directory is unknown.
    def change_directory_target
      return unless words.first == 'cd'
      return '~' if words.length == 1
      return if words.length > 2 || words[1].start_with?('-') || words[1].include?('$')

      words[1]
    end

    def git?
      !words.empty? && git_word?(words.first)
    end

    # Something other than git runs, with git and then push among its words:
    # a wrapper the hook does not know, timeout or nohup say, that may hand
    # them on. A directory named git, or git after push, is an argument.
    def wraps_push?
      git_at = words.index { |word| git_word?(word) }
      push_at = words.index('push')
      !git_at.nil? && !push_at.nil? && git_at < push_at
    end

    def git_arguments
      words.drop(1)
    end

    def directory_unknown?
      @assignments.any? { |word| DIRECTORY_ASSIGNMENT.match?(word) }
    end

    # The GIT_CONFIG_* variable set for the command, if one is.
    def config_override
      @assignments.find { |word| CONFIG_ASSIGNMENT.match?(word) }&.split('=', 2)&.first
    end

    private

    # git by name or by path, as in /usr/bin/git.
    def git_word?(word)
      word == 'git' || word.end_with?('/git')
    end

    def without_redirections(words)
      rest = words.dup
      kept = []
      until rest.empty?
        word = rest.shift
        if REDIRECTION_OPERATOR.match?(word) then rest.shift
        elsif !REDIRECTION.match?(word) then kept << word
        end
      end
      kept
    end
  end

  # git's own options before the subcommand: each -C names a directory
  # relative to the one before it, --git-dir and --work-tree point git
  # somewhere the hook does not follow, an option the hook does not know
  # ends the reading, and a -c that changes what push does is remembered.
  class GitCommand
    FLAGS = %w[--no-pager -p --paginate -P --no-replace-objects --bare --literal-pathspecs --glob-pathspecs
               --noglob-pathspecs --icase-pathspecs --no-optional-locks --no-lazy-fetch].freeze
    WITH_ARGUMENT = %w[-c --namespace --exec-path --config-env].freeze
    INLINE_ARGUMENT = /\A--(?:namespace|exec-path|config-env|super-prefix)=/.freeze
    MOVES_REPOSITORY = /\A--(?:git-dir|work-tree)(?:=|\z)/.freeze
    # alias.* can rename push; branch.*, remote.*, push.* and url.* change
    # what, where and how it pushes.
    PUSH_CONFIG = /\A(?:alias|branch|remote|push|url)\./i.freeze

    attr_reader :directories, :subcommand, :arguments, :unknown_option, :config_override

    def initialize(arguments)
      @arguments = arguments.dup
      @directories = []
      @directory_unknown = false
      read_options
    end

    def push?
      subcommand == 'push'
    end

    def directory_unknown?
      @directory_unknown
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
      case word
      when '-C' then @directories << @arguments.shift.to_s
      when MOVES_REPOSITORY then lose_directory(word)
      when *WITH_ARGUMENT then note_config(word, @arguments.shift)
      when INLINE_ARGUMENT then note_config(word[/\A--[a-z-]+/], word.split('=', 2).last)
      else return FLAGS.include?(word)
      end
      true
    end

    def lose_directory(word)
      @arguments.shift unless word.include?('=')
      @directory_unknown = true
    end

    def note_config(option, value)
      return unless %w[-c --config-env].include?(option)

      key = value.to_s.split('=', 2).first.to_s
      @config_override ||= key if PUSH_CONFIG.match?(key)
    end
  end

  # The text a Script writes, with what the glued-redirection test needs kept
  # as it grows, the last character and whether the word under way is digits
  # alone, so a long text is not read again at each operator.
  class ScannedText
    COMMENT_START = /[\s;&|()]/.freeze
    OPERATOR_END = /[<>&|;()]/.freeze

    attr_reader :text, :last

    def initialize
      @text = +''
      @last = nil
      @word_length = 0
      @word_digits = true
    end

    # Appends +string+ and gives its length.
    def write(string)
      string.each_char { |char| note(char) }
      @text << string
      string.length
    end

    # A # here starts a comment: at the start, after whitespace or glued to
    # an operator.
    def comment_start?
      @last.nil? || COMMENT_START.match?(@last)
    end

    # A word an operator is run against: not the digits of 2>&1, not the
    # second character of an operator, not nothing.
    def glued?
      @word_length.positive? && !@word_digits && !OPERATOR_END.match?(@last)
    end

    private

    def note(char)
      @last = char
      if char.match?(/\s/)
        @word_length = 0
        @word_digits = true
      else
        @word_length += 1
        @word_digits &&= char.match?(/\d/)
      end
    end
  end

  # The here-documents a line opens, read as bash reads them: each delimiter
  # word is noted at its << (quotes removed, since they say the body is
  # literal while the word is the same), and when the line ends each body is
  # copied out as it is up to its terminator line, tabs allowed before the
  # terminator for <<-, with no quote or escape read in it.
  class HereDocuments
    # A delimiter word, quoted in whole, in part or not at all.
    DELIMITER = /\A(?:'[^']*'|"[^"]*"|\\.|[^\s<>&|;()'"\\])+/.freeze
    # The delimiter is read from this many characters after the operator,
    # rather than from a copy of the rest of the text; one longer is cut, so
    # its body runs to the end and leaves the text unbalanced, which is safe.
    WINDOW = 128

    def initialize(chars, out)
      @chars = chars
      @out = out
      @pending = []
      @terminated = true
    end

    # Whether every body so far ended at its terminator line; one that ran to
    # the end of the text was not read as bash will read it.
    def terminated?
      @terminated
    end

    # Reads the operator and delimiter at +index+ as text and notes the
    # delimiter, unless there is none to note; gives the count consumed.
    def open(index)
      rest = @chars[index, WINDOW].join
      head = rest[/\A<<-?[ \t]*/]
      raw = rest[head.length..][DELIMITER].to_s
      @pending << [raw.delete("'\"\\"), head.start_with?('<<-')] unless raw.empty?
      @out.write(head + raw)
    end

    # Copies out the bodies the line opened, from +index+; gives the count
    # consumed.
    def bodies(index)
      consumed = 0
      @pending.each do |delimiter, tabs|
        consumed += body(index + consumed) { |line| (tabs ? line.sub(/\A\t+/, '') : line) == delimiter }
      end
      @pending.clear
      consumed
    end

    private

    def body(index)
      consumed = 0
      while index + consumed < @chars.length
        line = Script.line_at(@chars, index + consumed)
        consumed += @out.write(line)
        return consumed if yield(line.chomp)
      end
      @terminated = false
      consumed
    end
  end

  # The Bash text as bash reads it, character by character with the quotes
  # and escapes tracked across the whole of it: a comment (a # at the start
  # of a line, after whitespace or glued to an operator, outside quotes) runs
  # to the end of its line and no further; a backslash-newline continues the
  # line outside single quotes; $'…' escapes like double quotes and closes on
  # '; a here-document's body passes through as it is; a redirection glued to
  # a word (master>log) is set apart as bash splits it, a quoted one is not;
  # parentheses count only unquoted. A quote still open at the end, or a
  # here-document with no terminator, means the text was not read as bash
  # will read it.
  class Script
    # A backslash-newline joined wherever it stands, line by line, for the
    # raw lines that back up a text whose quotes the scan could not follow.
    def self.join_continuations(command)
      command.gsub(/(?<!\\)((?:\\\\)*)\\\n/, '\1')
    end

    # The line at +index+ of +chars+ with its newline, or the rest of them.
    def self.line_at(chars, index)
      finish = index
      finish += 1 while finish < chars.length && chars[finish] != "\n"
      chars[index..finish].join
    end

    def initialize(command)
      @chars = command.chars
      @out = ScannedText.new
      @heredocs = HereDocuments.new(@chars, @out)
      @quote = nil
      @subshell = false
      @arithmetic = 0
      index = 0
      index += step(index) while index < @chars.length
    end

    # What the text left open, for the reason given when the raw lines cannot
    # settle a push.
    def open_construct
      @quote ? 'an unclosed quote' : 'an unterminated here-document'
    end

    def text
      @out.text
    end

    def balanced?
      @quote.nil? && @heredocs.terminated?
    end

    # Where a subshell may hide: unquoted parentheses, or a text whose quotes
    # the hook could not follow.
    def subshell?
      @subshell || !balanced?
    end

    private

    # Reads the character at +index+ and gives the count consumed. The quote
    # state is the closing character, or $' for ANSI-C quoting, which closes
    # on ' but escapes as double quotes do.
    def step(index)
      char = @chars[index]
      return quoted(char, "'") if @quote == "'"
      return escaped(index) if char == '\\'
      return quoted(char, @quote[-1]) if @quote

      unquoted(index, char)
    end

    def quoted(char, closing)
      @quote = nil if char == closing
      @out.write(char)
    end

    # A backslash-newline continues the line and is dropped; any other escape
    # is kept whole for Shellwords to read.
    def escaped(index)
      following = @chars[index + 1]
      @out.write("\\#{following}") unless following == "\n"
      following.nil? ? 1 : 2
    end

    def unquoted(index, char)
      case char
      when '#' then hash(index)
      when "\n" then @out.write(char) + @heredocs.bodies(index + 1)
      when "'", '"' then open_quote(char)
      when '$' then dollar(index)
      when '(', ')' then parenthesis(char)
      when '<', '>', '&' then operator(index, char)
      else @out.write(char)
      end
    end

    # A comment to the end of its line, the newline left to end the segment,
    # or a # in a word.
    def hash(index)
      @out.comment_start? ? Script.line_at(@chars, index).chomp.length : @out.write('#')
    end

    def open_quote(char)
      @quote = char
      @out.write(char)
    end

    def dollar(index)
      return @out.write('$') unless @chars[index + 1] == "'"

      @quote = "$'"
      @out.write("$'")
    end

    # ((…)) and $((…)) are arithmetic, where << is a shift; their parentheses
    # are counted so the context closes with them. Any other parenthesis may
    # open a subshell.
    def parenthesis(char)
      if @arithmetic.positive?
        @arithmetic += char == '(' ? 1 : -1
      elsif char == '(' && @out.last == '('
        @arithmetic = 2
      else
        @subshell = true
      end
      @out.write(char)
    end

    # A redirection glued to a word is set apart; << opens a here-document,
    # while <<< is a here-string and opens nothing, nor does a shift.
    def operator(index, char)
      return @out.write(char) if @arithmetic.positive?

      @out.write(' ') if @out.glued?
      return @out.write(char) unless char == '<' && @chars[index + 1] == '<'
      return @out.write('<<<') if @chars[index + 2] == '<'

      @heredocs.open(index)
    end
  end

  # Reads the Bash text into the pushes it holds, following cd between
  # commands as far as it can, and into asks for what it cannot read.
  class CommandReader
    # A newline, ;, pipe, &&, ||, |& or a background &, but not the & of
    # 2>&1, >&2 or &>file.
    SEPARATORS = /\n|;|&&|\|\||\|&|\||(?<![<>])&(?!>)/.freeze
    # Behind these the text no longer says what runs.
    OPAQUE = [/`/, /\$\(/, /\beval\b/, /\bxargs\b/, /\b(?:ba|z|da|k|fi)?sh\s+-[A-Za-z]*c\b/].freeze

    attr_reader :pushes, :decisions

    # A cd inside a subshell is not inherited by the next command; the hook
    # does not read the nesting, so with +subshell+ any cd loses the
    # directory.
    def initialize(command, cwd, subshell)
      @command = command
      @cwd = cwd
      @subshell = subshell
      @pushes = []
      @decisions = []
    end

    def read
      construct = OPAQUE.map { |pattern| @command[pattern] }.compact.first
      if construct
        ask(Reasons.unreadable(construct)) if @command.include?('git') && @command.include?('push')
      else
        @command.split(SEPARATORS).each { |text| read_segment(text.delete('()')) }
      end
      self
    end

    private

    def ask(reason)
      @decisions << Decision.ask(reason)
    end

    # Asks only where the segment mentions push: the rest of a command is
    # not the hook's business.
    def ask_about_push(text, reason)
      ask(reason) if text.include?('push')
    end

    # A cd is followed before the $ test, since Shellwords keeps a $d whole
    # and a cd "$d" must lose the directory rather than be passed over.
    def read_segment(text)
      words = split(text)
      return ask_about_push(text, Reasons::UNBALANCED_QUOTES) if words.nil?

      segment = Segment.new(words)
      return follow(segment) if segment.change_directory?
      return ask_about_push(text, Reasons::VARIABLE) if text.include?('$')

      read_words(segment, text)
    end

    def read_words(segment, text)
      return ask_about_push(text, Reasons.prefix_option(segment.prefix_option)) if segment.prefix_option
      return read_git(segment, text) if segment.git?

      ask(Reasons.unreadable(segment.words.first)) if segment.wraps_push?
    end

    # A push-shaping -c or GIT_CONFIG_* variable is asked about whether or
    # not the segment says push: an alias can give push any name.
    def read_git(segment, text)
      git = GitCommand.new(segment.git_arguments)
      override = segment.config_override || git.config_override
      if git.unknown_option
        ask_about_push(text, Reasons.unknown_git_option(git.unknown_option))
      elsif override
        ask(Reasons.config_override(override))
      elsif git.push?
        @pushes << Push.new(git.arguments, push_directory(segment, git))
      end
    end

    # nil once the directory is unknown: after a cd the hook could not
    # follow, or under GIT_DIR, GIT_WORK_TREE, --git-dir or --work-tree.
    def push_directory(segment, git)
      return if segment.directory_unknown? || git.directory_unknown?

      git.directories.reduce(@cwd) { |from, path| Directory.follow(from, path) }
    end

    def follow(segment)
      target = segment.change_directory_target unless @subshell
      @cwd = target.nil? ? nil : Directory.follow(@cwd, target)
    end

    def split(text)
      Shellwords.split(text)
    rescue ArgumentError
      nil
    end
  end

  # Read-only questions to git in one directory; nil where git has no answer.
  # The repository's own configuration can name programs (a signature
  # verifier, a file monitor, a pager), so those are switched off here.
  class Repository
    # In a partial clone a log, or check-mailmap with mailmap.blob set, can
    # fetch a missing object from the promisor remote, which runs that
    # remote's uploadpack before anyone has answered. GIT_NO_LAZY_FETCH
    # forbids it on git 2.45 and later and on the May 2024 patch releases
    # (2.39.4, 2.40.2, 2.41.1, 2.42.2, 2.43.4, 2.44.1); any other git ignores
    # it, so an empty GIT_ALLOW_PROTOCOL refuses every transport as the
    # backstop. A read that needs a missing object then fails, or goes on
    # without it, and neither reaches the remote.
    ENVIRONMENT = { 'GIT_OPTIONAL_LOCKS' => '0', 'GIT_NO_LAZY_FETCH' => '1', 'GIT_ALLOW_PROTOCOL' => '' }.freeze
    GIT = %w[git --no-pager -c core.fsmonitor=false -c log.showSignature=false].freeze
    DESTINATION_FORMAT = '%(refname)%00%(push:remotename)%00%(push:short)'
    # Keeps the log within the hook's timeout on a branch of any length; a
    # log that reaches it may hide older authors, so it is asked about rather
    # than counted.
    MAX_COMMITS = 1000

    def initialize(directory)
      @directory = directory
      @fetch_refspecs = {}
    end

    # Whether every fetch refspec of +remote+ that could take a branch lands
    # it under refs/remotes/<remote>/ by its own name, as the default layout
    # does, so the push atoms and the tracking refs the hook reads name what
    # git pushes over. A line with no destination fetches into FETCH_HEAD
    # alone and has no bearing.
    def default_fetch_layout?(remote)
      fetch_refspecs(remote).all? do |source, into|
        into.empty? || !branch_source?(source) || by_name?(source, into, remote)
      end
    end

    # The first of +refs+ that a fetch refspec of +remote+ from a source that
    # cannot take a branch fills, its one * matching across slashes as git's
    # do, so the ref holds something other than the branch of its name; nil
    # where none does.
    def filled_from_elsewhere(remote, refs)
      elsewhere = fetch_refspecs(remote).reject { |source, into| into.empty? || branch_source?(source) }
      refs.find { |ref| elsewhere.any? { |_source, into| refspec_match?(into, ref) } }
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

    # Where git would push +branch+ with no refspec, as [remote name, short
    # destination] from its push atoms, resolved for +remote+ when the
    # command names one; both empty where git has no answer, nil where it
    # fails. The pattern also lists refs/heads/<branch>/..., so the exact
    # line is taken.
    def push_destination(branch, remote)
      override = remote ? ['-c', "branch.#{branch}.pushRemote=#{remote}"] : []
      output = git(*override, 'for-each-ref', "--format=#{DESTINATION_FORMAT}", "refs/heads/#{branch}")
      return if output.nil?

      line = output.lines.find { |candidate| candidate.start_with?("refs/heads/#{branch}\0") }
      _refname, atom, short = line.to_s.chomp.split("\0", 3)
      [atom.to_s, short.to_s]
    end

    # user.email as .mailmap maps it; nil where it is not set.
    def own_email
      email = config('user.email').to_s
      return if email.empty?

      git('check-mailmap', "<#{email}>").to_s[/<([^>]*)>/, 1] || email
    end

    # The refs matching +patterns+ as for-each-ref matches them, a literal
    # exactly and a * within one path segment; none where git fails.
    def refs(patterns)
      git('for-each-ref', '--format=%(refname)', *patterns).to_s.lines.map(&:chomp)
    end

    # [email, name] per commit of +ref+ beyond every ref in +excluded+,
    # newest first and MAX_COMMITS at most, the email as .mailmap maps it and
    # otherwise as the commit has it; nil when git cannot read them. Identity
    # is the email alone; the name is kept because a bot is known by its name.
    def authors(ref, excluded)
      output = git('log', '--no-show-signature', "--max-count=#{MAX_COMMITS}", '--format=%aE%x00%aN', ref, '--not',
                   *excluded)
      return if output.nil?

      output.lines.map do |line|
        email, name = line.chomp.split("\0", 2)
        [email.to_s, name.to_s]
      end
    end

    private

    # [source, destination] per fetch refspec of +remote+, the + stripped;
    # read once per remote.
    def fetch_refspecs(remote)
      @fetch_refspecs[remote] ||= git('config', '--get-all', "remote.#{remote}.fetch").to_s.lines.map do |line|
        source, into = line.chomp.sub(/\A\+/, '').split(':', 2)
        [source.to_s, into.to_s]
      end
    end

    # Whether the refspec is the by-name mapping, refs/heads/X to
    # refs/remotes/<remote>/X; a short name stands for refs/heads/<name>.
    def by_name?(source, into, remote)
      full = source.start_with?('refs/') || source.include?('*') ? source : "refs/heads/#{source}"
      into == full.sub(%r{\Arefs/heads/}, "refs/remotes/#{remote}/")
    end

    # Whether a refspec pattern takes +ref+: its one * matches anything,
    # slashes included, as git's refspec globs do.
    def refspec_match?(pattern, ref)
      prefix, suffix = pattern.split('*', 2)
      return pattern == ref if suffix.nil?

      ref.start_with?(prefix) && ref.end_with?(suffix) && ref.length >= prefix.length + suffix.length
    end

    # Whether a fetch source could take a branch: refs/heads/… itself, a
    # short name git resolves to one, or a * within its first two segments
    # (refs/*, refs/heads*, *), which git matches first when it is listed
    # first. Tags, pull requests, notes and the like cannot, nor does a
    # negative refspec, which only removes.
    def branch_source?(source)
      return false if source.start_with?('^')

      head, second = source.split('/', 3)
      head != 'refs' || second == 'heads' || second.to_s.include?('*')
    end

    # git writes bytes, read here as UTF-8 whatever the locale says, so a
    # non-ASCII name or address is text and not an encoding error.
    def git(*arguments)
      stdout, _stderr, status = Open3.capture3(ENVIRONMENT, *GIT, *arguments, chdir: @directory)
      status.success? ? stdout.force_encoding(Encoding::UTF_8).scrub.chomp : nil
    end
  end

  # Where a push with no refspec goes. git resolves it for the current branch
  # under push.default, remote.pushDefault and branch.<name>.pushRemote, and
  # for the remote the command names when it names one, so the hook keeps
  # none of those rules itself. Two settings the push atoms fold away,
  # push.default=matching and a configured remote.<name>.push, are read from
  # config and asked about, as are a detached HEAD and a git that fails.
  class Destination
    attr_reader :remote, :branch, :ask

    def initialize(repository, named_remote)
      @repository = repository
      @named_remote = named_remote
      resolve
    end

    private

    def resolve
      return refuse(Reasons.every_branch('push.default=matching')) if matching?

      current = @repository.current_branch
      resolved = @repository.push_destination(current, @named_remote) unless current.nil?
      return refuse(Reasons::UNRESOLVED_DESTINATION) if resolved.nil?

      place(*resolved, current)
    end

    # The remote and branch from the push atoms' remote name and short
    # destination.
    def place(atom, short, current)
      @remote = remote_name(atom)
      return refuse(Reasons.remapped_fetch(remote)) unless @repository.default_fetch_layout?(remote)
      return refuse(Reasons.every_branch("the configured remote.#{remote}.push")) if configured_refspec?

      @branch = branch_name(short, current)
    end

    def refuse(reason)
      @ask = Decision.ask(reason)
    end

    def matching?
      @repository.config('push.default') == 'matching'
    end

    def configured_refspec?
      !@repository.config("remote.#{remote}.push").nil?
    end

    # The remote-name atom is empty where no configuration names one, which
    # is where git falls back to origin.
    def remote_name(atom)
      [@named_remote, atom, 'origin'].find { |name| !name.to_s.empty? }
    end

    # The short destination is <remote>/<branch>, and empty where git would
    # refuse the push; the current branch then stands, so a checkout of a
    # base branch is still denied.
    def branch_name(short, current)
      branch = short.to_s.delete_prefix("#{remote}/")
      branch.empty? ? current : branch
    end
  end

  # Whether people other than the pusher have commits on the remote's copy
  # of the branch beyond its base, as an ask; nil where none have, and where
  # there is no copy to read and git needs none.
  class AuthorCheck
    BOT_NAME = /\[bot\]\z/i.freeze
    GITHUB_ACTIONS = /github-actions/i.freeze

    def initialize(repository, remote, branch, copy_needed)
      @repository = repository
      @remote = remote
      @branch = branch
      @copy_needed = copy_needed
    end

    def ask
      return Decision.ask(Reasons.remapped_fetch(remote)) unless repository.default_fetch_layout?(remote)

      filled_ask([tracking_ref]) || copy_ask
    end

    # Once the tracking ref is the branch of its name: whether it is here,
    # who the pusher is, then the branch beyond its bases.
    def copy_ask
      return missing_copy unless repository.ref?(tracking_ref)

      own = repository.own_email
      return Decision.ask(Reasons::NO_EMAIL) if own.nil?

      base_ask(own)
    end

    # A ref the check reads that a fetch from elsewhere fills holds something
    # other than the branch of its name, so nothing read through it counts.
    def filled_ask(refs)
      filled = repository.filled_from_elsewhere(remote, refs)
      Decision.ask(Reasons.filled_tracking_ref(remote, filled)) if filled
    end

    # The branch beyond its bases, once the default branch's copy is here
    # and every base read is the branch of its name.
    def base_ask(own)
      base, mend = base_and_mend
      return unreadable(mend) unless repository.ref?(base)

      bases = ([base] + fetched_bases).uniq
      filled_ask(bases) || strangers_ask(own, bases)
    end

    private

    attr_reader :repository, :remote, :branch

    def tracking_ref
      "refs/remotes/#{remote}/#{branch}"
    end

    # A bare lease expects the remote-tracking ref, so without one git itself
    # rejects the rewrite as stale information and nothing is checked. A
    # lease with a value in it rewrites without one, and a deletion removes
    # the remote branch whether or not it was ever fetched, so for those the
    # copy is needed to read the authors and its absence asks.
    def missing_copy
      unreadable("git fetch #{remote} #{branch}") if @copy_needed
    end

    # The remote's copy of its default branch, with the command that brings
    # it here when it is not: a fetch of that branch, or set-head where the
    # remote's HEAD itself is not known and master is assumed.
    def base_and_mend
      default = repository.default_branch(remote)
      return ["refs/remotes/#{remote}/master", "git remote set-head #{remote} -a"] if default.nil?

      ["refs/remotes/#{remote}/#{default}", "git fetch #{remote} #{default}"]
    end

    def unreadable(mend)
      Decision.ask(Reasons.unreadable_history(branch, remote, mend))
    end

    # Every base fetched from the remote, since the branch is measured beyond
    # all of them and not the default branch alone: a pull-request branch
    # under project/<id>/ carries all of project/<id>/master, which is not
    # its own authors' doing.
    def fetched_bases
      repository.refs(BASE_BRANCHES.map { |pattern| "refs/remotes/#{remote}/#{pattern}" })
    end

    def strangers_ask(own, excluded)
      authors = repository.authors(tracking_ref, excluded)
      return unreadable("git fetch #{remote} #{branch}") if authors.nil?
      return long_history(excluded) if authors.length == Repository::MAX_COMMITS

      addresses = strangers(authors, own)
      return if addresses.empty?

      Decision.ask(Reasons.other_authors(branch, remote, addresses))
    end

    # A log that fills the bound may have older commits, and authors, below
    # it, so it cannot be counted.
    def long_history(excluded)
      range = "#{tracking_ref} --not #{excluded.join(' ')}"
      Decision.ask(Reasons.long_history(branch, remote, Repository::MAX_COMMITS, range))
    end

    # The addresses on the branch that are neither the pusher's nor a bot's,
    # lower-cased and each once.
    def strangers(authors, own)
      strangers = authors.reject { |email, name| own.casecmp?(email) || bot?(email, name) }
      strangers.map { |email, _name| email.downcase }.uniq
    end

    def bot?(email, name)
      BOT_NAME.match?(name) || GITHUB_ACTIONS.match?(name) || GITHUB_ACTIONS.match?(email)
    end
  end

  # The decision for one push. The order is the point: what needs no question
  # to git is settled first (a bare force denied, an option not understood
  # asked about, a plain push left to the permission rules, a push whose
  # targets cannot be named asked about, a refspec naming a base branch
  # denied), so a deny never waits on git and a directory the hook lost track
  # of is asked about before git is asked anything; then the targets git
  # names are checked against the bases; and last, since it can only add an
  # ask, the authors on the remote's copy.
  class Judge
    def initialize(push, repository = nil)
      @push = push
      @repository = repository
    end

    def decide
      decide_from_text || (decide_targets if push.destructive?)
    end

    # What the text of the push settles on its own: a bare force, an option
    # not understood, and for a destructive push a refspec naming a base
    # branch outright. A reading of the command that may be wrong about the
    # current branch contributes no more.
    def decide_from_text
      return Decision.deny(Reasons::BARE_FORCE) if push.bare_force?
      return Decision.ask(Reasons.unknown_push_option(push.unknown_option)) if push.unknown_option
      return unless push.destructive?

      Decision.strictest(base_denies(refspec_targets))
    end

    # For a text bash would not run as written, a quote or here-document left
    # open: what the text settles, else an ask for a destructive push, since
    # the reading may be wrong about it and no valid command pays for the ask.
    def decide_from_text_or_ask(construct)
      decide_from_text || (Decision.ask(Reasons.unreadable(construct)) if push.destructive?)
    end

    private

    attr_reader :push

    def repository
      @repository ||= Repository.new(push.directory)
    end

    # --delete with no refspec is a push git refuses, so nothing is decided.
    def decide_targets
      return if push.deletes? && push.refspecs.empty?

      decisions = decisions_without_git
      return Decision.strictest(decisions) if decisions.any?(&:deny?)
      return Decision.strictest(decisions << Decision.ask(Reasons::UNKNOWN_DIRECTORY)) if push.directory.nil?

      Decision.strictest(decisions_with_git(decisions))
    end

    def decisions_without_git
      [unnamed_targets_ask, *base_denies(refspec_targets)].compact
    end

    def base_denies(targets)
      targets.map { |branch, deleting| base_deny(branch, deleting) }
    end

    def unnamed_targets_ask
      reason = unnamed_targets_reason
      Decision.ask(reason) if reason
    end

    # --prune, --all with a lease, a wildcard or the matching refspec: the
    # remote decides what they touch.
    def unnamed_targets_reason
      return Reasons.prune if push.prune?
      return Reasons.every_branch('--all with a lease') if push.all? && push.lease?

      refspec = push.refspecs.find { |candidate| candidate.wildcard? || candidate.matching? }
      Reasons.every_branch("the refspec #{refspec.text}") if refspec
    end

    # [branch, deleting] for each refspec the hook reads on its own.
    def refspec_targets
      push.refspecs.select(&:named?).map { |refspec| [refspec.destination, deleting?(refspec)] }
    end

    def deleting?(refspec)
      push.deletes? || refspec.deletion?
    end

    def base_deny(branch, deleting)
      return unless base?(branch) && (deleting || push.rewrites?)

      Decision.deny(Reasons.base_branch(branch))
    end

    def base?(branch)
      BASE_BRANCHES.any? { |pattern| File.fnmatch(pattern, branch, File::FNM_PATHNAME) }
    end

    # The targets git names, the current branch behind HEAD or where a push
    # with no refspec goes, checked against the bases; then every target's
    # authors, unless an ask is already in hand.
    def decisions_with_git(decisions)
      targets = resolved_targets
      decisions += [destination&.ask, *base_denies(targets)].compact
      return decisions unless decisions.empty?

      author_asks(push.remote || destination.remote, refspec_targets + targets)
    end

    # Where a push with no refspec goes; nil where refspecs name the targets.
    def destination
      return unless push.refspecs.empty?

      @destination ||= Destination.new(repository, push.remote)
    end

    def resolved_targets
      return destination.branch ? [[destination.branch, false]] : [] if destination

      refspecs = push.refspecs.select(&:current_branch?)
      current = repository.current_branch unless refspecs.empty?
      current ? refspecs.map { |refspec| [current, deleting?(refspec)] } : []
    end

    def author_asks(remote, targets)
      targets.uniq.map { |branch, deleting| author_ask(remote, branch, deleting) }
    end

    def author_ask(remote, branch, deleting)
      return unless push.lease? || deleting

      AuthorCheck.new(repository, remote, branch, deleting || push.lease_value?).ask
    end
  end

  # The hook event on stdin, as far as the hook reads it: which tool, and for
  # Bash the command and the directory it runs in. The sh entry hands over
  # any stdin that says push, so the event may be no event at all.
  class Event
    def initialize(json)
      parsed = JSON.parse(json)
      @fields = parsed.is_a?(Hash) ? parsed : {}
      @readable = parsed.is_a?(Hash) && parsed['tool_name'].is_a?(String)
    rescue JSON::ParserError
      @fields = {}
      @readable = false
    end

    def readable?
      @readable
    end

    def bash?
      @fields['tool_name'] == 'Bash'
    end

    # The Bash command, or nil where tool_input is not an object holding one.
    def command
      input = @fields['tool_input']
      input['command'] if input.is_a?(Hash) && input['command'].is_a?(String)
    end

    def cwd
      @fields['cwd'].is_a?(String) ? @fields['cwd'] : Dir.pwd
    end
  end

  # The entry: one event in, at most one decision out, and a failure is an
  # ask. So is input that is not a hook event.
  class Hook
    # The event is UTF-8 whatever the locale says, like git's output, and a
    # byte that is not is read as text rather than failing the read.
    def self.run(input, output)
      decision = new(Event.new(input.read.force_encoding(Encoding::UTF_8).scrub)).decision
      output.puts(decision.to_json) if decision
    rescue StandardError => e
      output.puts(Decision.ask(Reasons.failure(e)).to_json)
    end

    def initialize(event)
      @event = event
    end

    def decision
      return Decision.ask(Reasons::UNREADABLE_INPUT) unless @event.readable?
      return unless @event.bash?
      return Decision.ask(Reasons::UNREADABLE_INPUT) unless @event.command

      decide(@event.command, @event.cwd)
    end

    private

    # The text as bash reads it decides everything. Where a quote is left
    # open the text was not read as bash will read it (a heredoc body, say),
    # so the raw lines are a backstop, contributing only what a push's text
    # settles, since apart they may be wrong about its targets.
    def decide(command, cwd)
      script = Script.new(command)
      decisions = decisions(script.text, cwd, script.subshell?, &:decide)
      return Decision.strictest(decisions) if script.balanced?

      backstop = decisions(Script.join_continuations(command), cwd, true) do |judge|
        judge.decide_from_text_or_ask(script.open_construct)
      end
      Decision.strictest(decisions + backstop)
    end

    def decisions(text, cwd, subshell, &judge)
      reader = CommandReader.new(text, cwd, subshell).read
      reader.decisions + reader.pushes.map { |push| judge.call(Judge.new(push)) }
    end
  end
end

PushGuard::Hook.run($stdin, $stdout)

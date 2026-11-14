# frozen_string_literal: true

require_relative 'checklist'
require_relative 'ledger'
require_relative 'scripts_checkout'
require_relative 'usage_error'
require_relative 'written_file'

module Do
  # The arguments of `record`, every one validated before anything else
  # runs: the subcommand, the issue as the user gave it (IssueLocator's to
  # judge), then the subcommand's flags, each with its value, in any order.
  module RecordArguments
    # Each subcommand's flags that take a value, beside the yes every one
    # takes, those it needs (all of +required+, exactly one of +one_of+, and
    # with each key of +needs+ its value), and whether it takes --dry-run.
    # Box positions come with the digest of the body facts counted them in.
    SUBCOMMANDS = {
      'closes' => { values: %w[--base --verified-items --verified-boxes --boxes-digest], required: %w[--base],
                    needs: { '--verified-boxes' => '--boxes-digest' } },
      'tick' => { values: %w[--ledger --issue-boxes --boxes-digest], one_of: %w[--ledger --issue-boxes],
                  needs: { '--issue-boxes' => '--boxes-digest', '--boxes-digest' => '--issue-boxes' }, dry_run: true },
      'gate add' => { values: %w[--finding-file], required: %w[--finding-file] },
      'gate answer' => { values: %w[--k --answer], required: %w[--k --answer] },
      'gate publish' => { values: %w[--k], required: %w[--k], dry_run: true },
      'gate mark' => { values: %w[--k --state], required: %w[--k --state], dry_run: true },
      'sub-issue' => { values: %w[--item --number], required: %w[--item --number], dry_run: true }
    }.transform_values { |spec| spec.merge(values: [*spec[:values], ScriptsCheckout::ACCEPT_FLAG]) }.freeze
    DRY_RUN = '--dry-run'
    LIST_SEPARATOR = ','
    LINE_ITEM_ID = /\A[LP][1-9][0-9]{0,5}\z/
    SUB_ISSUE_ID = /\A(?:#{Ledger::REPOSITORY})?#[1-9][0-9]{0,9}\z/
    POSITION = /\A[1-9][0-9]{0,5}\z/
    GATE_ID = /\AG[1-9][0-9]{0,5}\z/
    # Answers and states as they go on a command line, and as the gate file
    # and the ledger write them.
    ANSWERS = { 'fix-here' => 'fix here', 'advisory' => 'advisory' }.freeze
    STATES = { 'fixed' => 'fixed', 'user-decided' => 'user decided' }.freeze
    # How each flag's value is checked, and turned into its option's value;
    # convert hands --base, --number, --finding-file, --boxes-digest and
    # --accept-scripts to the checks other modules own.
    CONVERTERS = {
      '--verified-items' => :ledger_ids!, '--ledger' => :ledger_ids!, '--verified-boxes' => :positions!,
      '--issue-boxes' => :positions!, '--k' => :gate_id!, '--answer' => :answer!, '--state' => :state!,
      '--item' => :item!
    }.freeze

    Options = Struct.new(:command, :reference, :base, :verified_items, :verified_boxes, :ledger, :issue_boxes,
                         :boxes_digest, :k, :finding_file, :answer, :state, :item, :number, :accept_scripts, :dry_run,
                         keyword_init: true)

    module_function

    # The Options in +arguments+. Raises RecordUsageError for an unknown
    # subcommand, or a flag it doesn't take, repeats or lacks, and
    # InvalidIdentifier for a value that isn't valid.
    def parse(arguments, runner:)
      command, rest = command(arguments)
      spec = SUBCOMMANDS.fetch(command) { raise RecordUsageError }
      reference, *flags = rest
      raise RecordUsageError if reference.nil? || reference.start_with?('-')

      values, dry_run = flags(flags, spec)
      Options.new(command: command, reference: reference, dry_run: dry_run,
                  **values.to_h { |flag, value| [option(flag), convert(flag, value, runner)] })
    end

    # "gate" takes its action as a second word.
    def command(arguments)
      first, *rest = arguments
      first == 'gate' ? ["gate #{rest.first}", rest.drop(1)] : [first, rest]
    end

    # The flags' values by flag, and whether --dry-run was given. A value
    # can't start with "-", so --dry-run is never one.
    def flags(flags, spec)
      dry_runs = flags.count(DRY_RUN)
      raise RecordUsageError if dry_runs > (spec[:dry_run] ? 1 : 0)

      [values(flags - [DRY_RUN], spec), dry_runs == 1]
    end

    def values(pairs, spec)
      raise RecordUsageError if pairs.length.odd?

      values = pairs.each_slice(2).to_h
      raise RecordUsageError unless values.length * 2 == pairs.length && (values.keys - spec[:values]).empty?

      check_presence(values.keys, spec)
      values
    end

    def check_presence(flags, spec)
      raise RecordUsageError unless (spec.fetch(:required, []) - flags).empty?
      raise RecordUsageError if spec[:one_of] && (spec[:one_of] & flags).length != 1

      needs = spec.fetch(:needs, {})
      raise RecordUsageError if needs.any? { |flag, needed| flags.include?(flag) && !flags.include?(needed) }
    end

    def option(flag)
      flag.delete_prefix('--').tr('-', '_').to_sym
    end

    def convert(flag, value, runner)
      case flag
      when '--base' then SkillSupport::Identifiers.branch!(value, runner: runner)
      when '--number' then SkillSupport::Identifiers.issue_number!(value)
      when '--finding-file' then WrittenFile.path!(:finding_file, value)
      when '--boxes-digest' then Checklist.digest!(value)
      when ScriptsCheckout::ACCEPT_FLAG then ScriptsCheckout.token!(value)
      else send(CONVERTERS.fetch(flag), value)
      end
    end

    def ledger_ids!(value)
      list(:ledger_id, value) { |id| LINE_ITEM_ID.match?(id) || SUB_ISSUE_ID.match?(id) }
    end

    def positions!(value)
      list(:box_position, value) { |position| POSITION.match?(position) }.map { |position| Integer(position, 10) }
    end

    # The comma-separated entries of +value+, each one the block accepts,
    # without repeats.
    def list(kind, value, &)
      entries = value.split(LIST_SEPARATOR, -1)
      raise SkillSupport::InvalidIdentifier.new(kind, value) if entries.empty? || !entries.all?(&)

      entries.uniq
    end

    def gate_id!(value)
      raise SkillSupport::InvalidIdentifier.new(:gate_id, value) unless GATE_ID.match?(value)

      value
    end

    def item!(value)
      raise SkillSupport::InvalidIdentifier.new(:ledger_item, value) unless LINE_ITEM_ID.match?(value)

      value
    end

    def answer!(value)
      ANSWERS.fetch(value) { raise SkillSupport::InvalidIdentifier.new(:answer, value) }
    end

    def state!(value)
      STATES.fetch(value) { raise SkillSupport::InvalidIdentifier.new(:state, value) }
    end

    private_class_method :command, :flags, :values, :check_presence, :option, :convert, :ledger_ids!, :positions!,
                         :list, :gate_id!, :item!, :answer!, :state!
  end
end

# frozen_string_literal: true

require_relative 'closes'
require_relative 'gate_record'
require_relative 'record_arguments'
require_relative 'scripts_checkout'
require_relative 'sub_issue_record'
require_relative 'tick'

module Do
  # skills/do/bin/record: /do's closing and recording. `closes` works out
  # what /do's PR closes and writes nothing; `tick`, `gate` and
  # `sub-issue` each edit one record in place: the ledger comment, the issue
  # body or the local gate file. Like `preflight check`, each first asks
  # about scripts that may not be the reviewed ones.
  module Record
    COMMANDS = { 'closes' => Closes, 'tick' => Tick, 'gate add' => GateRecord::Add, 'gate answer' => GateRecord::Answer,
                 'gate publish' => GateRecord::Publish, 'gate mark' => GateRecord::Mark,
                 'sub-issue' => SubIssueRecord }.freeze

    module_function

    # +skill_directory+ is where the running scripts live.
    def call(arguments, runner: SkillSupport::CommandRunner.new, skill_directory: ScriptsCheckout::SKILL_DIRECTORY)
      options = RecordArguments.parse(arguments, runner: runner)
      scripts = ScriptsCheckout.new(runner, skill_directory: skill_directory).examine(accepted: options.accept_scripts)
      return unreviewed(scripts) if scripts.ask

      COMMANDS.fetch(options.command).new(options, runner: runner).call
    rescue BodyChanged
      Reasons.stop(Reasons::BODY_CHANGED)
    rescue AmbiguousCheckbox => e
      Reasons.stop(Reasons::AMBIGUOUS_CHECKBOX, target: e.target, lines: e.lines)
    end

    # The ask for scripts that may not be the reviewed ones, naming their
    # checkout and changes in the session alone.
    def unreviewed(scripts)
      SkillSupport::Outcome.ask([scripts.ask], session_only: { scripts_checkout: scripts.top_level,
                                                               scripts_changes: scripts.changes.map(&:to_s) })
    end

    private_class_method :unreviewed
  end
end

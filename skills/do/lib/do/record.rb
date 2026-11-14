# frozen_string_literal: true

require_relative 'closes'
require_relative 'gate_record'
require_relative 'record_arguments'
require_relative 'sub_issue_record'
require_relative 'tick'

module Do
  # skills/do/bin/record: /do's closing and recording. `closes` works out
  # what step 7's PR closes and writes nothing; `tick`, `gate` and
  # `sub-issue` each edit one record in place: the ledger comment, the issue
  # body or the local gate file.
  module Record
    COMMANDS = { 'closes' => Closes, 'tick' => Tick, 'gate add' => GateRecord::Add, 'gate answer' => GateRecord::Answer,
                 'gate publish' => GateRecord::Publish, 'gate mark' => GateRecord::Mark,
                 'sub-issue' => SubIssueRecord }.freeze

    module_function

    def call(arguments, runner: SkillSupport::CommandRunner.new)
      options = RecordArguments.parse(arguments, runner: runner)
      COMMANDS.fetch(options.command).new(options, runner: runner).call
    rescue BodyChanged
      Reasons.stop(Reasons::BODY_CHANGED)
    end
  end
end

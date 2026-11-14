# frozen_string_literal: true

require_relative 'checklist'
require_relative 'reasons'
require_relative 'record_issue'

module Do
  # `record tick <issue> (--ledger IDS | --issue-boxes POSITIONS)
  # [--dry-run]`: ticks the boxes QA verified, in the ledger comment or, when
  # its author is trusted, the issue body. Each box named must be exactly
  # one top-level box outside code fences, or nothing is written. Only
  # "[ ]" becomes "[x]", through BodyEdit's one-writer discipline; nothing
  # is written when every box is ticked already. The output names boxes by
  # id or position, never quoting the body.
  class Tick
    # +options+ are RecordArguments' Options.
    def initialize(options, runner:)
      @options = options
      @runner = runner
    end

    def call
      RecordIssue.locate(@options.reference, runner: @runner) do |issue|
        @options.ledger ? tick_ledger(issue) : tick_issue_body(issue)
      end
    end

    private

    def tick_ledger(issue)
      return Reasons.stop(Reasons::NO_LEDGER) unless issue.ledger

      items, missing = issue.ledger.resolve(@options.ledger)
      return Reasons.stop(Reasons::BOX_MISSING, missing: missing) unless missing.empty?

      tick(issue.ledger_body, issue.ledger.comment.body, @options.ledger.zip(items), target: :ledger)
    end

    def tick_issue_body(issue)
      return Reasons.stop(Reasons::UNTRUSTED_ISSUE_AUTHOR) unless issue.issue_author_trusted?

      body = issue.issue_body
      before = body.read
      boxes, missing = Checklist.at(Checklist.boxes(before), @options.issue_boxes)
      return Reasons.stop(Reasons::BOX_MISSING, missing: missing) unless missing.empty?

      tick(body, before, @options.issue_boxes.zip(boxes), target: :issue_body)
    end

    # +named+ pairs each id or position the call gave with its box, a ledger
    # Item or a Checklist Box.
    def tick(body, before, named, target:)
      ticked, unticked = named.partition { |_name, box| box.checked }
      unless @options.dry_run || unticked.empty?
        body.write(before, Checklist.tick(before, unticked.map { |_name, box| box.line }))
      end
      SkillSupport::Outcome.proceed(target: target, flipped: unticked.map(&:first), already: ticked.map(&:first),
                                    dry_run: @options.dry_run)
    end
  end
end

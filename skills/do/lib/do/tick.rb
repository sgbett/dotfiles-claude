# frozen_string_literal: true

require_relative 'checklist'
require_relative 'reasons'
require_relative 'record_issue'

module Do
  # `record tick <issue> (--ledger IDS | --issue-boxes POSITIONS
  # --boxes-digest D) [--dry-run]`: ticks the boxes QA verified, in the
  # ledger comment or, when its author is trusted, the issue body, whose
  # boxes must still be the ones facts counted, with digest D. Each box
  # named must be exactly one of the body's boxes as Checklist reads them,
  # and the body must hold no line that reads like a box Checklist can't
  # place, or nothing is written. Only "[ ]" becomes "[x]", through
  # BodyEdit's one-writer discipline; nothing is written when every box is
  # ticked already, and a dry run takes no lock. The output names boxes by
  # id or position, never quoting the body.
  class Tick
    # +options+ are RecordArguments' Options.
    def initialize(options, runner:)
      @options = options
      @runner = runner
    end

    def call
      RecordIssue.locate(@options.reference, runner: @runner, writes: !@options.dry_run) do |issue|
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

      before, all = issue.issue_boxes(@options.boxes_digest)
      boxes, missing = Checklist.at(all, @options.issue_boxes)
      return Reasons.stop(Reasons::BOX_MISSING, missing: missing) unless missing.empty?

      tick(issue.issue_body, before, @options.issue_boxes.zip(boxes), target: :issue_body)
    end

    # +named+ pairs each id or position the call gave with its box, a ledger
    # Item or a Checklist Box.
    def tick(body, before, named, target:)
      ticked, unticked = named.partition { |_name, box| box.checked }
      body.write(before, Checklist.tick(before, unticked.map(&:last))) unless @options.dry_run || unticked.empty?
      SkillSupport::Outcome.proceed(target: target, flipped: unticked.map(&:first), already: ticked.map(&:first),
                                    dry_run: @options.dry_run)
    end
  end
end

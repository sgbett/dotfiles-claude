# frozen_string_literal: true

require_relative 'checklist'
require_relative 'closing'
require_relative 'reasons'
require_relative 'record_issue'

module Do
  # `record closes <issue> --base B [--verified-items IDS] [--verified-boxes
  # POSITIONS]`, which writes nothing: the issues /do's PR closes under
  # the Closing rule, as `Closes #N` lines when B is this repository's
  # default branch, where GitHub acts on them, or else as the numbers the
  # lead closes by hand; and every issue left open, with why. One that may
  # not be named on GitHub is listed only under "session_only".
  class Closes
    # +options+ are RecordArguments' Options.
    def initialize(options, runner:)
      @options = options
      @runner = runner
    end

    def call
      RecordIssue.locate(@options.reference, runner: @runner) { |issue| decide(issue) }
    end

    private

    def decide(issue)
      return Reasons.stop(Reasons::NO_LEDGER) unless issue.ledger

      boxes = Checklist.boxes(issue.issue_body.read) if issue.criteria_in_body?
      items, verified_boxes, missing = verified(issue.ledger, boxes)
      return Reasons.stop(Reasons::BOX_MISSING, missing: missing) unless missing.empty?

      report(issue.view, Closing.new(issue.view, boxes: boxes, verified_items: items, verified_boxes: verified_boxes))
    end

    # The ledger items and the boxes QA verified, and the ids and positions
    # that name none. Positions name boxes only where the body holds the
    # criteria.
    def verified(ledger, boxes)
      items, missing_items = ledger.resolve(@options.verified_items || [])
      found, missing_boxes = boxes ? Checklist.at(boxes, @options.verified_boxes || []) : [[], []]
      [items, found, missing_items + missing_boxes]
    end

    def report(view, closing)
      nameable, hidden = closing.held.partition { |held| view.nameable?(held.record) }
      SkillSupport::Outcome.proceed(**closing_fields(view.query.default_branch_ref, closing),
                                    criteria: closing.criteria, held: listed(view, nameable),
                                    session_only: { held: listed(view, hidden) })
    end

    # GitHub acts on closing keywords only in a pull request into the
    # default branch.
    def closing_fields(default_branch, closing)
      base_is_default = @options.base == default_branch
      numbers = closing.closing
      { base: @options.base, default_branch: default_branch, base_is_default: base_is_default,
        closes_lines: base_is_default ? numbers.map { |number| "Closes ##{number}" } : [],
        close_by_hand: base_is_default ? [] : numbers }
    end

    def listed(view, held)
      held.map do |entry|
        { reference: view.reference(entry.record), reasons: entry.reasons, unverified: entry.unverified }.compact
      end
    end
  end
end

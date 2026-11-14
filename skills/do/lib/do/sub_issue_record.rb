# frozen_string_literal: true

require_relative 'ledger_edits'
require_relative 'reasons'
require_relative 'record_issue'

module Do
  # `record sub-issue <issue> --item ID --number M [--dry-run]`: the
  # rewrite of a ledger item as "- [ ] #M <title>", once the lead has
  # created sub-issue #M. The title comes from GitHub's list of the issue's
  # sub-issues, never from an argument, and only a trusted author's goes in
  # the ledger.
  class SubIssueRecord
    CONTROL_CHARACTER = /[[:cntrl:]]/

    # +options+ are RecordArguments' Options.
    def initialize(options, runner:)
      @options = options
      @runner = runner
    end

    def call
      RecordIssue.locate(@options.reference, runner: @runner, writes: !@options.dry_run) { |issue| rewrite(issue) }
    end

    private

    def rewrite(issue)
      sub_issue = issue.sub_issue_here(@options.number)
      refusal = refusal(issue, sub_issue)
      return refusal if refusal
      return done(already: [:ledger]) if rewritten?(issue.ledger)
      return Reasons.stop(Reasons::BOX_MISSING, missing: [@options.item]) unless rewritable?(issue.ledger)

      write(issue, item(issue.ledger).line, title(sub_issue))
    end

    def refusal(issue, sub_issue)
      return Reasons.stop(Reasons::NO_LEDGER) unless issue.ledger
      return Reasons.stop(Reasons::NOT_A_SUB_ISSUE) unless sub_issue

      Reasons.stop(Reasons::UNTRUSTED_SUB_ISSUE) unless issue.view.trust.issue(sub_issue).trusted
    end

    # The item the call names, when exactly one box has its id.
    def item(ledger)
      ledger.resolve([@options.item]).first.first
    end

    # Already rewritten, as a run cut short after its write leaves it.
    def rewritten?(ledger)
      item(ledger).nil? && boxes_naming(ledger) == 1
    end

    def rewritable?(ledger)
      item(ledger)&.kind == :item && boxes_naming(ledger).zero?
    end

    def boxes_naming(ledger)
      ledger.items.count { |entry| entry.id == reference }
    end

    def write(issue, line, title)
      before = issue.ledger.comment.body
      after = LedgerEdits.replace(before, [line], "- [ ] #{reference} #{title}")
      check(issue, after)
      issue.ledger_body.write(before, after) unless @options.dry_run
      done(updated: [:ledger])
    end

    # The rewritten line must read back as the sub-issue's box.
    def check(issue, after)
      return if issue.ledger_with(after).resolve([reference]).first.first&.kind == :sub_issue

      raise SkillSupport::UnexpectedResponse, "the ledger wouldn't read #{reference} as a sub-issue"
    end

    def reference
      "##{@options.number}"
    end

    # The sub-issue's title, which goes on the ledger line as it is: a line
    # break in it would start a line of its own.
    def title(sub_issue)
      title = sub_issue.title
      unless title.is_a?(String) && !title.strip.empty? && !CONTROL_CHARACTER.match?(title)
        raise SkillSupport::UnexpectedResponse, "#{reference} came back without a one-line title"
      end

      title
    end

    def done(updated: [], already: [])
      SkillSupport::Outcome.proceed(item: @options.item, number: @options.number, updated: updated,
                                    already: already, dry_run: @options.dry_run)
    end
  end
end

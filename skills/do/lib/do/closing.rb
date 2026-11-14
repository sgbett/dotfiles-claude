# frozen_string_literal: true

module Do
  # The owner's closing rule (sgbett/dotfiles-claude#24), which replaced two
  # that disagreed: the issue closes only when QA has verified every
  # acceptance box, and no sub-issue in another repository is still open,
  # one whose author isn't trusted counting as open. Each of this
  # repository's sub-issues in the ledger closes once its box is verified.
  # A box already ticked was verified by an earlier run.
  class Closing
    CLOSED = 'CLOSED'

    # An issue left open: the issue itself, a sub-issue here, or one
    # elsewhere. +unverified+, for the issue, lists the boxes (positions) or
    # ledger items (ids) QA has yet to verify.
    Held = Struct.new(:record, :reasons, :unverified, keyword_init: true)

    # +view+ is the issue's IssueView, which has a ledger. +boxes+ are the
    # Checklist boxes of the issue body, nil when its criteria live in the
    # ledger. +verified_items+ are the ledger Items, and +verified_boxes+
    # the issue body's Boxes, QA verified.
    def initialize(view, boxes:, verified_items:, verified_boxes:)
      @view = view
      @boxes = boxes
      @item_positions = verified_items.map(&:position)
      @box_positions = verified_boxes.map(&:position)
    end

    # :issue_boxes, or :ledger_items when the body holds no boxes, or isn't
    # where the criteria live.
    def criteria
      @boxes.nil? || @boxes.empty? ? :ledger_items : :issue_boxes
    end

    # The numbers of the issues to close, the issue's first.
    def closing
      issue_number = issue.number if issue_reasons.empty?
      [issue_number, *verified_sub_issues].compact.uniq
    end

    def held
      unless issue_reasons.empty?
        issue_held = Held.new(record: issue, reasons: issue_reasons, unverified: (unverified unless unverified.empty?))
      end
      [issue_held, *sub_issues_held, *elsewhere_held].compact
    end

    private

    def issue
      @view.query.issue
    end

    def issue_reasons
      @issue_reasons ||= [criteria_reason, *elsewhere_reasons(elsewhere)].compact
    end

    def criteria_reason
      return if unverified.empty?

      criteria == :issue_boxes ? :unverified_boxes : :unverified_items
    end

    # Why +records+, sub-issues in other repositories, hold an issue open.
    def elsewhere_reasons(records)
      [(:open_elsewhere if records.any? { |record| open?(record) }),
       (:untrusted_elsewhere unless records.all? { |record| trusted?(record) })].compact
    end

    def unverified
      @unverified ||= criteria == :issue_boxes ? unverified_boxes : unverified_items
    end

    def unverified_boxes
      @boxes.reject { |box| box.checked || @box_positions.include?(box.position) }.map(&:position)
    end

    # A sub-issue elsewhere is never built here; the rule for those settles
    # it instead.
    def unverified_items
      @view.ledger.items.reject { |item| item.kind == :sub_issue_elsewhere || verified?(item) }.map(&:id)
    end

    def verified?(item)
      item.checked || @item_positions.include?(item.position)
    end

    def sub_issue_items
      @view.ledger.items.select { |item| item.kind == :sub_issue }
    end

    def verified_sub_issues
      sub_issue_items.select { |item| verified?(item) }.map { |item| item.sub_issue.number }
    end

    # This repository's open sub-issues that QA hasn't verified, in the
    # ledger or not.
    def sub_issues_held
      open_here = @view.query.sub_issues.select { |sub_issue| @view.here?(sub_issue) && open?(sub_issue) }
      open_here.reject { |sub_issue| verified_sub_issues.include?(sub_issue.number) }.map do |sub_issue|
        Held.new(record: sub_issue, reasons: [in_ledger?(sub_issue) ? :unverified_items : :not_in_ledger])
      end
    end

    def in_ledger?(sub_issue)
      sub_issue_items.any? { |item| item.sub_issue.number == sub_issue.number }
    end

    def elsewhere
      @view.query.sub_issues.reject { |sub_issue| @view.here?(sub_issue) }
    end

    def elsewhere_held
      elsewhere.filter_map do |sub_issue|
        reasons = elsewhere_reasons([sub_issue])
        Held.new(record: sub_issue, reasons: reasons) unless reasons.empty?
      end
    end

    # A state GitHub didn't give counts as open.
    def open?(record)
      record.state != CLOSED
    end

    def trusted?(record)
      @view.trust.issue(record).trusted
    end
  end
end

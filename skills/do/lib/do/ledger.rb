# frozen_string_literal: true

require_relative 'checklist'
require_relative 'gate_state'
require_relative 'visibility'

module Do
  # The breakdown comment (the Ledger of /do's SKILL.md): the issue's work as
  # the top-level boxes of its checklist, as Checklist reads them, plain
  # "Gate G<k>: <state>" lines, and the acceptance criteria adopted for an
  # untrusted author under a fixed heading. A line in code or an HTML
  # comment, which GitHub shows quoted or not at all, is neither of those.
  class Ledger
    MARKER = '<!-- do:breakdown -->'
    LINE_ITEM = /\A\*\*(?<id>L[1-9][0-9]*)(?![0-9A-Za-z])/
    REPOSITORY = %r{#{SkillSupport::Identifiers::OWNER}/#{SkillSupport::Identifiers::REPOSITORY_NAME}}
    SUB_ISSUE = /\A(?<repository>#{REPOSITORY})?#(?<number>[1-9][0-9]*)(?![0-9A-Za-z])/
    GATE_LINE = /\AGate (?<id>G[1-9][0-9]*):(?<state>.*)\z/
    ADOPTED_CRITERIA = '### Adopted acceptance criteria'
    QUOTED_OR_HIDDEN = %i[code comment].freeze

    # +id+ is "L<n>" for a box starting **L<n>; for a sub-issue, "#M" in this
    # repository or "owner/repo#M" in another that may be named; otherwise
    # "P<position>", the box's place among the ledger's boxes. +kind+ is
    # :item, :sub_issue (in this repository) or :sub_issue_elsewhere, and
    # +sub_issue+ the sub-issue's IssueRecord. +line+, for items and gate
    # lines alike, is the index among the body's lines, and +mark+ the
    # offset of an item's mark in its line.
    Item = Struct.new(:id, :position, :line, :mark, :kind, :checked, :sub_issue, keyword_init: true)
    Gate = Struct.new(:id, :state, :line, keyword_init: true)

    attr_reader :comment, :gates

    # Returns the ledger comment, the earliest beginning with MARKER whose
    # author +trusted+ accepts (or nil), and the marker comments whose
    # authors it rejects.
    def self.locate(comments, &)
      markers = comments.select { |comment| comment.body.to_s.start_with?(MARKER) }
      [markers.find(&), markers.reject(&)]
    end

    # +sub_issues+ are the IssueRecords GraphQL lists as the issue's
    # sub-issues; a box naming any other issue is a plain item. +home+ is
    # this repository.
    def initialize(comment, sub_issues:, home:)
      @comment = comment
      @sub_issues = sub_issues
      @home = home
      @gates = []
      @adopted_criteria = false
      lines = BlockReader.read(comment.body)
      boxes, @ambiguous = Checklist.read(lines)
      @items = boxes.map { |box| item(box) }
      lines.each { |line| read(line.text, line.index) unless line.task || QUOTED_OR_HIDDEN.include?(line.hidden) }
    end

    def adopted_criteria?
      @adopted_criteria
    end

    # The checklist's items. Raises AmbiguousCheckbox when a line reads like
    # a box /do can't place, as no item's id or position can then be relied
    # on; the gate lines stand regardless.
    def items
      raise AmbiguousCheckbox.new(:ledger, @ambiguous) unless @ambiguous.empty?

      @items
    end

    # The first unticked item this run builds: a line item or a sub-issue in
    # this repository. A sub-issue elsewhere is tracked, never built.
    def first_unbuilt
      items.find { |item| !item.checked && item.kind != :sub_issue_elsewhere }
    end

    # The items each of +ids+ names, and the ids that name no box, or more
    # than one when boxes repeat an id.
    def resolve(ids)
      found = ids.map { |id| items.select { |item| item.id == id } }
      [found.select(&:one?).map(&:first), ids.select.with_index { |_id, index| !found[index].one? }]
    end

    private

    def read(line, index)
      if (gate = GATE_LINE.match(line))
        @gates << Gate.new(id: gate[:id], state: GateState.parse(gate[:state]), line: index)
      elsif line.rstrip == ADOPTED_CRITERIA
        @adopted_criteria = true
      end
    end

    # The item a Checklist Box is.
    def item(box)
      place = { position: box.position, line: box.line, mark: box.mark, checked: box.checked }
      line_item = LINE_ITEM.match(box.text)
      return Item.new(id: line_item[:id], kind: :item, **place) if line_item

      sub_issue = linked_sub_issue(box.text)
      return Item.new(id: "P#{box.position}", kind: :item, **place) unless sub_issue

      Item.new(id: sub_issue_id(sub_issue, box.position), kind: sub_issue_kind(sub_issue), sub_issue: sub_issue,
               **place)
    end

    # The sub-issue a box starting "#M" or "owner/repo#M" names, if GraphQL
    # lists that repository and number among the sub-issues.
    def linked_sub_issue(text)
      match = SUB_ISSUE.match(text)
      return unless match

      name = match[:repository] || @home.name_with_owner
      number = Integer(match[:number], 10)
      @sub_issues.find { |sub_issue| sub_issue.number == number && sub_issue.repository.name_with_owner.casecmp?(name) }
    end

    def sub_issue_kind(sub_issue)
      sub_issue.repository.same_as?(@home) ? :sub_issue : :sub_issue_elsewhere
    end

    def sub_issue_id(sub_issue, position)
      return "##{sub_issue.number}" if sub_issue.repository.same_as?(@home)
      return "P#{position}" unless Visibility.nameable?(sub_issue.repository, @home)

      "#{sub_issue.repository.name_with_owner}##{sub_issue.number}"
    end
  end
end

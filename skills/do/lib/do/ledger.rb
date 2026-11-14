# frozen_string_literal: true

require_relative 'checklist'
require_relative 'gate_state'
require_relative 'markdown'
require_relative 'visibility'

module Do
  # The breakdown comment (the Ledger of /do's SKILL.md): the issue's work as
  # top-level checklist boxes, plain "Gate G<k>: <state>" lines, and the
  # acceptance criteria adopted for an untrusted author under a fixed
  # heading. Boxes and lines inside fenced code blocks don't count.
  class Ledger
    MARKER = '<!-- do:breakdown -->'
    LINE_ITEM = /\A\*\*(?<id>L[1-9][0-9]*)(?![0-9A-Za-z])/
    REPOSITORY = %r{#{SkillSupport::Identifiers::OWNER}/#{SkillSupport::Identifiers::REPOSITORY_NAME}}
    SUB_ISSUE = /\A(?<repository>#{REPOSITORY})?#(?<number>[1-9][0-9]*)(?![0-9A-Za-z])/
    GATE_LINE = /\AGate (?<id>G[1-9][0-9]*):(?<state>.*)\z/
    ADOPTED_CRITERIA = '### Adopted acceptance criteria'

    # +id+ is "L<n>" for a box starting **L<n>; for a sub-issue, "#M" in this
    # repository or "owner/repo#M" in another that may be named; otherwise
    # "P<position>", the box's place among the ledger's boxes. +kind+ is
    # :item, :sub_issue (in this repository) or :sub_issue_elsewhere, and
    # +sub_issue+ the sub-issue's IssueRecord. +line+, for items and gate
    # lines alike, is the index among the body's lines.
    Item = Struct.new(:id, :position, :line, :kind, :checked, :sub_issue, keyword_init: true)
    Gate = Struct.new(:id, :state, :line, keyword_init: true)

    attr_reader :comment, :items, :gates

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
      @items = []
      @gates = []
      @adopted_criteria = false
      Markdown.lines_with_fences(comment.body).each_with_index do |(line, fenced), index|
        read(line, index) unless fenced
      end
    end

    def adopted_criteria?
      @adopted_criteria
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
      if (box = Checklist::BOX.match(line))
        @items << item(box, @items.length + 1, index)
      elsif (gate = GATE_LINE.match(line))
        @gates << Gate.new(id: gate[:id], state: GateState.parse(gate[:state]), line: index)
      elsif line.rstrip == ADOPTED_CRITERIA
        @adopted_criteria = true
      end
    end

    def item(box, position, line)
      place = { position: position, line: line, checked: box[:mark] != Checklist::UNTICKED }
      text = box[:text].to_s.lstrip
      line_item = LINE_ITEM.match(text)
      return Item.new(id: line_item[:id], kind: :item, **place) if line_item

      sub_issue = linked_sub_issue(text)
      return Item.new(id: "P#{position}", kind: :item, **place) unless sub_issue

      Item.new(id: sub_issue_id(sub_issue, position), kind: sub_issue_kind(sub_issue), sub_issue: sub_issue, **place)
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

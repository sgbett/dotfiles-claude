# frozen_string_literal: true

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
    # Unindented, as /do writes "- [ ] ...": a nested box is detail, not an item.
    BOX = /\A[-*+] \[(?<mark>[ xX])\](?: (?<text>.*))?\z/
    LINE_ITEM = /\A\*\*(?<id>L[1-9][0-9]*)(?![0-9A-Za-z])/
    REPOSITORY = %r{#{SkillSupport::Identifiers::OWNER}/#{SkillSupport::Identifiers::REPOSITORY_NAME}}
    SUB_ISSUE = /\A(?<repository>#{REPOSITORY})?#(?<number>[1-9][0-9]*)(?![0-9A-Za-z])/
    GATE_LINE = /\AGate (?<id>G[1-9][0-9]*):(?<state>.*)\z/
    ADOPTED_CRITERIA = '### Adopted acceptance criteria'

    # +id+ is "L<n>" for a box starting **L<n>; for a sub-issue, "#M" in this
    # repository or "owner/repo#M" in another that may be named; otherwise
    # "P<position>", the box's place among the ledger's boxes. +kind+ is
    # :item, :sub_issue (in this repository) or :sub_issue_elsewhere, and
    # +sub_issue+ the sub-issue's IssueRecord.
    Item = Struct.new(:id, :position, :kind, :checked, :sub_issue, keyword_init: true)
    Gate = Struct.new(:id, :state, keyword_init: true)

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
      Markdown.unfenced_lines(comment.body).each { |line| read(line) }
    end

    def adopted_criteria?
      @adopted_criteria
    end

    # The first unticked item this run builds: a line item or a sub-issue in
    # this repository. A sub-issue elsewhere is tracked, never built.
    def first_unbuilt
      items.find { |item| !item.checked && item.kind != :sub_issue_elsewhere }
    end

    private

    def read(line)
      if (box = BOX.match(line))
        @items << item(box, @items.length + 1)
      elsif (gate = GATE_LINE.match(line))
        @gates << Gate.new(id: gate[:id], state: GateState.parse(gate[:state]))
      elsif line.rstrip == ADOPTED_CRITERIA
        @adopted_criteria = true
      end
    end

    def item(box, position)
      checked = box[:mark] != ' '
      text = box[:text].to_s.lstrip
      line_item = LINE_ITEM.match(text)
      return Item.new(id: line_item[:id], position: position, kind: :item, checked: checked) if line_item

      sub_issue = linked_sub_issue(text)
      return Item.new(id: "P#{position}", position: position, kind: :item, checked: checked) unless sub_issue

      Item.new(id: sub_issue_id(sub_issue, position), position: position, kind: sub_issue_kind(sub_issue),
               checked: checked, sub_issue: sub_issue)
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

# frozen_string_literal: true

require_relative 'block_reader'

module Do
  # Lines of a body read like checklist boxes that /do can't place as
  # GitHub reads them. Not a tool failure: the scripts stop with
  # Reasons::AMBIGUOUS_CHECKBOX, naming the body and the lines (from 1).
  class AmbiguousCheckbox < StandardError
    attr_reader :target, :lines

    # +target+ is :issue_body or :ledger.
    def initialize(target, lines)
      @target = target
      @lines = lines
      super("#{target} lines #{lines.join(', ')} read like boxes /do can't place")
    end
  end

  # A body's checklist as GitHub reads it: its top-level task-list items, a
  # list item ("-", "*", "+", "1." or "1)") indented up to three spaces
  # outside any other list item or block quote, then "[ ]", "[x]" or "[X]",
  # then a space or the line's end. A box nested in another item is detail,
  # and one in code or an HTML block is text. A line that reads like a box
  # but isn't one /do can place, such as one with no list marker, a tab or
  # odd spacing, makes the body ambiguous rather than a guess. Ticking a box
  # turns its "[ ]" into "[x]" and leaves every other byte of the body as it
  # was.
  module Checklist
    TICKED = 'x'
    UNTICKED_BOX = '[ ]'
    LABEL_LENGTH = 60

    # +position+ is the box's place among the body's boxes, from 1; +line+
    # its index among the body's lines and +mark+ the offset of its mark in
    # that line. +text+ is GitHub text.
    Box = Struct.new(:position, :line, :mark, :checked, :text, keyword_init: true) do
      # The start of the box's text, to name it by.
      def label
        text.length > LABEL_LENGTH ? "#{text[0, LABEL_LENGTH - 1]}…" : text
      end
    end

    module_function

    # The boxes of +body+, the +target+'s text. Raises AmbiguousCheckbox when
    # a line reads like a box /do can't place.
    def boxes(body, target:)
      found, ambiguous = read(BlockReader.read(body))
      raise AmbiguousCheckbox.new(target, ambiguous) unless ambiguous.empty?

      found
    end

    # The Boxes among +lines+, BlockReader's reading of a body, and the
    # numbers (from 1) of the lines that make it ambiguous.
    def read(lines)
      found = []
      ambiguous = []
      lines.each do |line|
        if line.task && !line.doubtful then found << box(line, found.length + 1)
        elsif ambiguous?(line) then ambiguous << (line.index + 1)
        end
      end
      [found, ambiguous]
    end

    # The boxes at +positions+, and the positions no box holds.
    def at(boxes, positions)
      found = positions.map { |position| boxes[position - 1] }
      [found.compact, positions.select.with_index { |_position, index| found[index].nil? }]
    end

    # +body+ with each of +boxes+ (anything with a Box's line and mark)
    # ticked.
    def tick(body, boxes)
      lines = body.lines
      boxes.each { |box| lines[box.line] = ticked(lines.fetch(box.line), box) }
      lines.join
    end

    # +line+ with +box+ ticked.
    def ticked(line, box)
      unless line[box.mark - 1, UNTICKED_BOX.length] == UNTICKED_BOX
        raise ArgumentError, "line #{box.line} holds no unticked box"
      end

      "#{line[0, box.mark]}#{TICKED}#{line[(box.mark + 1)..]}"
    end

    def box(line, position)
      Box.new(position: position, line: line.index, mark: line.task.mark, checked: line.task.checked,
              text: line.task.text)
    end

    # A carriage return GitHub reads as a line break, or a box-like line
    # outside a quote and any nested item, where a top-level box could be:
    # one whose structure GitHub may read otherwise, or outside code and
    # HTML that runs to a closing string.
    def ambiguous?(line)
      return true if line.text.include?(BlockReader::CARRIAGE_RETURN)
      return false unless line.box_like && !line.quoted && line.depth <= 1

      line.doubtful || [nil, :html].include?(line.hidden)
    end

    private_class_method :ticked, :box, :ambiguous?
  end
end

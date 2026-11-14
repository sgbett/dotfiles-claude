# frozen_string_literal: true

require 'digest'
require_relative 'block_reader'

module Do
  # Lines of a body read like checklist boxes that /do can't place as
  # GitHub reads them. Not a tool failure: the scripts that act on boxes
  # stop with Reasons::AMBIGUOUS_CHECKBOX, naming the body and the lines
  # (from 1).
  class AmbiguousCheckbox < StandardError
    attr_reader :target, :lines

    # +target+ is :issue_body or :ledger.
    def initialize(target, lines)
      @target = target
      @lines = lines
      super("#{target} lines #{lines.join(', ')} read like boxes /do can't place")
    end
  end

  # A body's checklist as GitHub reads it: its task-list items, each a list
  # item ("-", "*", "+", "1." or "1)") whose content starts with "[ ]",
  # "[x]" or "[X]", then a space and text. The issue body's boxes are all
  # of them, in document order, nested or quoted, as GitHub counts them;
  # the ledger's are its top-level ones, outside any other item or quote,
  # a nested one being detail. One in code or an HTML block is text. A line
  # that reads like a box but isn't one /do can place makes the body
  # ambiguous rather than a guess: one with no list marker, a tab, odd
  # spacing or nothing after the box, one whose paragraph GitHub makes a
  # heading or a table, or one in a footnote definition, whose boxes GitHub
  # renders after the body, or not at all. Ticking a box turns its "[ ]"
  # into "[x]" and leaves every other byte of the body as it was.
  module Checklist
    TICKED = 'x'
    UNTICKED_BOX = '[ ]'
    LABEL_LENGTH = 60
    DIGEST = /\A[0-9a-f]{64}\z/
    # GitHub reads a body from after one leading byte order mark.
    BYTE_ORDER_MARK = "\uFEFF"

    # +position+ is the box's place among the body's boxes, from 1; +line+
    # its index among the body's lines and +mark+ the offset of its mark in
    # that line. +text+ is GitHub text.
    Box = Struct.new(:position, :line, :mark, :checked, :text, keyword_init: true) do
      # The start of the box's text, to name it by.
      def label
        text.length > LABEL_LENGTH ? "#{text[0, LABEL_LENGTH - 1]}…" : text
      end
    end

    # A body as Checklist read it: its Boxes, the numbers (from 1) of the
    # lines that make it ambiguous, and the SHA-256 digest of the body,
    # which ties the boxes' positions to the text they were counted in.
    Reading = Struct.new(:boxes, :ambiguous, :digest, keyword_init: true) do
      def ambiguous?
        !ambiguous.empty?
      end
    end

    module_function

    # +value+, a Reading's digest, as --boxes-digest takes it.
    def digest!(value)
      return value if value.is_a?(String) && DIGEST.match?(value)

      raise SkillSupport::InvalidIdentifier.new(:boxes_digest, value)
    end

    # The Reading of +body+, the +target+'s text.
    def scan(body, target:)
      found, ambiguous = read(BlockReader.read(text(body)), target: target)
      Reading.new(boxes: found, ambiguous: ambiguous, digest: Digest::SHA256.hexdigest(body.to_s))
    end

    # +body+ as GitHub reads it, without one leading byte order mark, which
    # the lines a Box names leave out.
    def text(body)
      body.to_s.delete_prefix(BYTE_ORDER_MARK)
    end

    # The Boxes among +lines+, BlockReader's reading of the +target+'s text,
    # and the numbers (from 1) of the lines that make it ambiguous.
    def read(lines, target:)
      nested = target == :issue_body
      found = []
      ambiguous = []
      lines.each do |line|
        if counted?(line, nested) then found << box(line, found.length + 1)
        elsif ambiguous?(line, nested) then ambiguous << (line.index + 1)
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
    # ticked; a byte order mark before them stays.
    def tick(body, boxes)
      lines = text(body).lines
      boxes.each { |box| lines[box.line] = ticked(lines.fetch(box.line), box) }
      "#{BYTE_ORDER_MARK if body.start_with?(BYTE_ORDER_MARK)}#{lines.join}"
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

    # A task item GitHub renders where the target's boxes are: at any depth
    # when +nested+, else at the top level.
    def counted?(line, nested)
      line.task && !line.doubtful && !line.footnote && (nested || top_level?(line))
    end

    # Outside any list item but its own, and any block quote.
    def top_level?(line)
      line.depth <= 1 && !line.quoted
    end

    # A carriage return GitHub reads as a line break, or a box-like line
    # where a counted box could be: one whose structure GitHub may read
    # otherwise, or outside code and HTML that runs to a closing string.
    def ambiguous?(line, nested)
      return true if line.text.include?(BlockReader::CARRIAGE_RETURN)
      return false unless line.box_like && (nested || top_level?(line))

      line.doubtful || [nil, :html].include?(line.hidden)
    end

    private_class_method :text, :ticked, :box, :counted?, :top_level?, :ambiguous?
  end
end

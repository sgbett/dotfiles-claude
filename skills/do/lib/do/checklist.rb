# frozen_string_literal: true

require_relative 'markdown'

module Do
  # The top-level checklist boxes of a Markdown body: unindented, as /do
  # writes "- [ ] ...", and outside fenced code blocks. A box nested under
  # another is detail, and one quoted in a fence is text. Ticking a box
  # turns its "[ ]" into "[x]" and leaves every other byte of the body as it
  # was.
  module Checklist
    BOX = /\A[-*+] \[(?<mark>[ xX])\](?: (?<text>.*))?\z/
    # The mark follows "- [", whichever bullet the box uses.
    MARK = 3
    UNTICKED = ' '
    TICKED = 'x'

    # +position+ is the box's place among the body's boxes, from 1; +line+
    # its index among the body's lines. +text+ is GitHub text.
    Box = Struct.new(:position, :line, :checked, :text, keyword_init: true)

    module_function

    def boxes(body)
      found = []
      Markdown.lines_with_fences(body).each_with_index do |(line, fenced), index|
        box = BOX.match(line) unless fenced
        next unless box

        found << Box.new(position: found.length + 1, line: index, checked: box[:mark] != UNTICKED,
                         text: box[:text].to_s.lstrip)
      end
      found
    end

    # The boxes at +positions+, and the positions no box holds.
    def at(boxes, positions)
      found = positions.map { |position| boxes[position - 1] }
      [found.compact, positions.select.with_index { |_position, index| found[index].nil? }]
    end

    # +body+ with the unticked box on each of +lines+, indices as Box#line
    # gives them, ticked.
    def tick(body, lines)
      raw = body.lines
      lines.each do |index|
        line = raw.fetch(index)
        raise ArgumentError, "line #{index} holds no unticked box" unless unticked?(line)

        raw[index] = "#{line[0, MARK]}#{TICKED}#{line[(MARK + 1)..]}"
      end
      raw.join
    end

    def unticked?(line)
      box = BOX.match(line.chomp)
      !box.nil? && box[:mark] == UNTICKED
    end

    private_class_method :unticked?
  end
end

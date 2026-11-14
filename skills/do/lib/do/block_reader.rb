# frozen_string_literal: true

require_relative 'block_line'
require_relative 'block_starts'
require_relative 'block_state'
require_relative 'line_scan'

module Do
  # Reads a Markdown body's block structure line by line as GitHub's
  # renderer, cmark-gfm, does, far enough to tell which lines open a
  # task-list item, and inside what: block quotes, footnote definitions and
  # list items, which hold other blocks, then paragraphs, fenced and
  # indented code, HTML blocks, headings and thematic breaks. A GFM table
  # reads as a paragraph, though a task whose paragraph may become one is
  # doubtful, as one whose paragraph becomes a heading is.
  class BlockReader
    CARRIAGE_RETURN = "\r"

    # The BlockLines of +body+.
    def self.read(body)
      reader = new
      body.to_s.each_line(chomp: true).with_index.map { |text, index| reader.read(text, index) }
    end

    def initialize
      @state = BlockState.new
    end

    # The BlockLine +raw+, the body's line at +index+, makes, given those
    # before.
    def read(raw, index)
      @scan = LineScan.new(raw)
      @line = BlockLine.new(index: index, text: raw, box_like: false, doubtful: raw.include?(CARRIAGE_RETURN))
      @matched = @state.match(@scan)
      hidden = @state.continue_leaf(@scan) if all_matched?
      hidden ? @line.hide(hidden, @scan) : open_blocks
      @line.quoted = @state.quoted?
      @line.footnote = @state.footnote?
      @line.depth = @state.depth
      @line
    end

    private

    def all_matched?
      @matched == @state.containers.length
    end

    # Opens the block quotes, footnote definitions and list items the line
    # starts, then the leaf block, or adds the line's text to a paragraph.
    def open_blocks
      @maybe_lazy = @state.paragraph?
      @interrupting = @maybe_lazy && all_matched? && !@scan.blank?
      @opened = false
      step = next_block
      step = next_block while step == :container
      add_text if step == :text
    end

    # :container when the line opens a container and may open more, :leaf
    # once it starts a leaf block, or :text. No leaf starts as a footnote
    # definition does, so that opens before them, wherever a list item could
    # start, as in cmark-gfm.
    def next_block
      return :text if @scan.blank?
      return indented_code if @scan.indent >= BlockState::CODE_INDENT
      return open_container(BlockState::QUOTE) if @scan.enter_quote
      return open_container(BlockState::FOOTNOTE) if @scan.enter_footnote_definition

      leaf_start || item_start || :text
    end

    # An indented code block can't interrupt a paragraph.
    def indented_code
      @maybe_lazy ? :text : start_leaf(BlockStarts::Leaf.new(:code, :code))
    end

    # A setext underline makes the open paragraph a heading.
    def leaf_start
      leaf = BlockStarts.leaf(@scan.rest, interrupting: @interrupting)
      return unless leaf

      @state.paragraph_start&.doubt_task if leaf.underline
      start_leaf(leaf)
    end

    def start_leaf(leaf)
      @state.close(@matched)
      @state.fill
      @state.leaf = leaf.block
      @line.hide(leaf.hidden, @scan) if leaf.hidden
      :leaf
    end

    def item_start
      marker = BlockStarts.list_marker(@scan.rest)
      return unless marker && (marker.interrupts_paragraph? || !@interrupting)

      @line.doubtful ||= list_after_lazy_line?(marker)
      open_item(@scan.first_nonspace, marker)
    end

    def open_item(start, marker)
      @line.open_item(@scan, start, marker)
      @scan.advance_to(start + marker.padding)
      open_container(BlockState::Item.new(kind: marker.kind, column: start + marker.padding, filled: !marker.blank))
    end

    # CommonMark reads an item that can't interrupt a paragraph, starting a
    # new list after a lazy line, as more of the paragraph; cmark-gfm opens
    # the list.
    def list_after_lazy_line?(marker)
      @maybe_lazy && !all_matched? && !@opened && !marker.interrupts_paragraph? &&
        !@state.continues_list?(@matched, marker)
    end

    def open_container(container)
      @state.close(@matched)
      @state.push(container)
      @matched = @state.containers.length
      @opened = true
      @interrupting = false
      :container
    end

    def add_text
      return close_at_blank_line if @scan.blank?

      @line.read_content(@scan)
      @state.fill
      return continue_paragraph if @maybe_lazy && !@opened

      @state.close(@matched)
      @state.open_paragraph(@line)
    end

    # A lazy line continues the paragraph open in a container it doesn't
    # continue, which stays open. A delimiter row, which can't be lazy,
    # straight after a paragraph's first line makes that line a table's
    # header.
    def continue_paragraph
      @state.continue_paragraph
      return unless all_matched? && @state.paragraph_lines == 2

      @state.paragraph_start.doubt_task if BlockStarts::DELIMITER_ROW.match?(@scan.rest)
    end

    def close_at_blank_line
      @state.close(@matched)
      @state.leaf = nil
    end
  end
end

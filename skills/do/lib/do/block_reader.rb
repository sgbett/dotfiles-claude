# frozen_string_literal: true

require_relative 'block_starts'
require_relative 'block_state'
require_relative 'line_scan'
require_relative 'task_item'

module Do
  # Reads a Markdown body's block structure line by line as GitHub's
  # renderer, cmark-gfm, does, far enough to tell which lines open a
  # top-level task-list item: block quotes and list items, which hold other
  # blocks, then paragraphs, fenced and indented code, HTML blocks, headings
  # and thematic breaks. A GFM table reads as a paragraph.
  class BlockReader
    CARRIAGE_RETURN = "\r"

    # A line as read. +hidden+ is :code, :comment, :raw (an HTML block that
    # runs to a closing string) or :html (one that runs to a blank line)
    # when GitHub shows the line as code or raw HTML, or nothing. +depth+ is
    # how many list items hold it, +task+ the TaskItem::Task of a top-level
    # task item the line starts, and +box_like+ whether its content reads
    # like a box. +doubtful+: GitHub's renderer may read the line's
    # structure otherwise, as with a carriage return it reads as a line
    # break.
    Line = Struct.new(:index, :text, :hidden, :quoted, :depth, :task, :box_like, :doubtful, keyword_init: true)

    def self.read(body)
      reader = new
      body.to_s.each_line(chomp: true).with_index.map { |text, index| reader.read(text, index) }
    end

    def initialize
      @state = BlockState.new
    end

    # The Line +raw+, the body's line at +index+, makes, given those before.
    def read(raw, index)
      @scan = LineScan.new(raw)
      @line = Line.new(index: index, text: raw, box_like: false, doubtful: raw.include?(CARRIAGE_RETURN))
      @matched = @state.match(@scan)
      hidden = @state.continue_leaf(@scan) if all_matched?
      hidden ? hide(hidden) : open_blocks
      @line.quoted = @state.quoted?
      @line.depth = @state.depth
      @line
    end

    private

    def all_matched?
      @matched == @state.containers.length
    end

    def hide(kind)
      @line.hidden = kind
      @line.box_like = TaskItem.box_like?(@scan.rest)
    end

    # Opens the block quotes and list items the line starts, then the leaf
    # block, or adds the line's text to a paragraph.
    def open_blocks
      @maybe_lazy = @state.paragraph?
      @interrupting = @maybe_lazy && all_matched? && !@scan.blank?
      @opened = false
      step = next_block
      step = next_block while step == :container
      add_text if step == :text
    end

    # :container when the line opens a block quote or list item and may open
    # more, :leaf once it starts a leaf block, or :text.
    def next_block
      return :text if @scan.blank?
      return indented_code if @scan.indent >= BlockState::CODE_INDENT
      return open_container(BlockState::QUOTE) if @scan.enter_quote

      leaf_start || item_start || :text
    end

    # An indented code block can't interrupt a paragraph.
    def indented_code
      @maybe_lazy ? :text : start_leaf(BlockStarts::Leaf.new(:code, :code))
    end

    def leaf_start
      leaf = BlockStarts.leaf(@scan.rest, interrupting: @interrupting)
      start_leaf(leaf) if leaf
    end

    def start_leaf(leaf)
      @state.close(@matched)
      @state.fill
      @state.leaf = leaf.block
      hide(leaf.hidden) if leaf.hidden
      :leaf
    end

    def item_start
      marker = BlockStarts.list_marker(@scan.rest)
      return unless marker && (marker.interrupts_paragraph? || !@interrupting)

      @line.doubtful ||= list_after_lazy_line?(marker)
      open_item(@scan.first_nonspace, marker)
    end

    def open_item(start, marker)
      read_task(start, marker) if @matched.zero?
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

    # A top-level item whose content reads like a box but isn't one is
    # doubtful.
    def read_task(start, marker)
      @line.task = TaskItem.task(@scan, start, marker)
      @line.doubtful ||= @line.task.nil? && TaskItem.box_like_content?(@scan, start, marker)
    end

    def open_container(container)
      @state.close(@matched)
      @state.push(container)
      @matched = @state.containers.length
      @opened = true
      @interrupting = false
      :container
    end

    # A lazy line continues the paragraph open in a container it doesn't
    # continue, which stays open.
    def add_text
      return close_at_blank_line if @scan.blank?

      @line.box_like = TaskItem.box_like?(@scan.rest)
      @state.fill
      return if @maybe_lazy && !all_matched? && !@opened

      @state.close(@matched)
      @state.leaf = :paragraph
    end

    def close_at_blank_line
      @state.close(@matched)
      @state.leaf = nil
    end
  end
end

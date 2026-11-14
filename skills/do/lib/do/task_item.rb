# frozen_string_literal: true

require_relative 'block_starts'

module Do
  # How a list item's line reads as a task: GitHub renders an item, at any
  # depth, whose content starts with a box as a task-list item. What merely
  # reads like a box is for Checklist to weigh.
  module TaskItem
    # A box, then text on its line: GitHub renders a box with nothing after
    # it as a task only when a nested block follows it in a tight list.
    BOX = /\A\[(?<mark>[ xX])\] +\S/
    BOX_WIDTH = 3
    # What a reader may take for a box: brackets around nothing, spaces or
    # an x.
    BRACKETS = /\[(?: {0,4}|[xX])\]/
    BOX_LIKE = /\A(?:(?:[-*+]|[0-9]{1,9}[.)]) *)?#{BRACKETS}/
    # An item's content GitHub may render as a box, past any leading
    # whitespace, Unicode's included: those brackets, or what GitHub reads as
    # them once it decodes escapes and character references and takes a
    # non-ASCII space for a space. So "\[" or "&" first, or "[" before a
    # space or anything but visible ASCII, before "\" or "&", or before an x
    # that "\" or "&" follows. "[Docs](url)" and "[WIP]" are neither.
    BOX_LIKE_CONTENT = /\A\p{Space}*(?:#{BRACKETS}|\\\[|&|\[(?:[^!-~]|[&\\]|[xX][&\\]))/

    # +mark+ is the offset of the box's mark in the line as written.
    Task = Struct.new(:mark, :checked, :text, keyword_init: true)

    module_function

    # The Task of the item whose +marker+ starts at column +start+ of
    # +scan+'s line, or nil. Its content must start with a box and text,
    # and no tab may come before the box's closing bracket, as GitHub counts
    # tabs in ways a column can't settle.
    def task(scan, start, marker)
      return if marker.blank || marker.spaces >= BlockStarts::CODE_PADDING

      content = start + marker.padding
      box = BOX.match(scan.text[content..])
      new_task(scan, content, box) if box && untabbed?(scan, content + BOX_WIDTH)
    end

    # Whether the item's content, after its marker, reads like a box.
    def box_like_content?(scan, start, marker)
      BOX_LIKE_CONTENT.match?(scan.text[(start + marker.width)..])
    end

    # Whether +text+, a line's content, reads like a box, after a list
    # marker or none.
    def box_like?(text)
      BOX_LIKE.match?(text)
    end

    # Whether the line as written and as read, its tabs expanded, agree up
    # to +column+.
    def untabbed?(scan, column)
      scan.raw[0, column] == scan.text[0, column]
    end

    def new_task(scan, content, box)
      Task.new(mark: content + 1, checked: box[:mark] != ' ', text: scan.text[(content + BOX_WIDTH)..].lstrip)
    end

    private_class_method :untabbed?, :new_task
  end
end

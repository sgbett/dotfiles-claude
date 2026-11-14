# frozen_string_literal: true

require_relative 'task_item'

module Do
  # A line as BlockReader reads it. +hidden+ is :code, :comment, :raw (an
  # HTML block that runs to a closing string) or :html (one that runs to a
  # blank line) when GitHub shows the line as code or raw HTML, or nothing.
  # +depth+ is how many list items hold it, +quoted+ and +footnote+ whether
  # a block quote or a footnote definition does, +task+ the TaskItem::Task
  # of a task item the line starts, at any depth, and +box_like+ whether its
  # content reads like a box. +doubtful+: GitHub's renderer may read the
  # line's structure otherwise, as with a carriage return it reads as a line
  # break, or a task's paragraph it makes a heading or a table.
  BlockLine = Struct.new(:index, :text, :hidden, :quoted, :footnote, :depth, :task, :box_like, :doubtful,
                         keyword_init: true) do
    # Shown as +kind+, its content starting at +scan+'s position.
    def hide(kind, scan)
      self.hidden = kind
      read_content(scan)
    end

    def read_content(scan)
      self.box_like = TaskItem.box_like?(scan.rest)
    end

    # Opens an item whose +marker+ starts at column +start+ of +scan+'s line:
    # one whose content reads like a box but isn't one is doubtful.
    def open_item(scan, start, marker)
      self.task = TaskItem.task(scan, start, marker)
      self.doubtful ||= task.nil? && TaskItem.box_like_content?(scan, start, marker)
    end

    # Its paragraph became a heading or a table, so GitHub may render its
    # task as none.
    def doubt_task
      self.doubtful = true if task
    end
  end
end

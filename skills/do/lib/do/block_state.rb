# frozen_string_literal: true

require_relative 'block_starts'

module Do
  # The blocks open in a Markdown body as BlockReader reads it: the block
  # quotes, footnote definitions and list items that hold the current line,
  # outermost first, and the leaf open in the innermost of them: :paragraph,
  # :code (indented), a BlockStarts::Fence or a BlockStarts::Html, or nil.
  # Of a paragraph, it keeps the line that opened it and how many it has.
  class BlockState
    QUOTE = :quote
    FOOTNOTE = :footnote
    CODE_INDENT = 4

    # A list item: +kind+ its marker's, +column+ where its content starts,
    # and +filled+ whether it holds anything yet.
    Item = Struct.new(:kind, :column, :filled, keyword_init: true)

    attr_reader :containers, :paragraph_start, :paragraph_lines
    attr_accessor :leaf

    def initialize
      @containers = []
      @leaf = nil
    end

    # Opens a paragraph at +line+, a BlockLine.
    def open_paragraph(line)
      @leaf = :paragraph
      @paragraph_start = line
      @paragraph_lines = 1
    end

    def continue_paragraph
      @paragraph_lines += 1
    end

    # How many containers, outermost first, +scan+'s line continues, the
    # scan moved past their markers.
    def match(scan)
      @containers.take_while { |container| enter(scan, container) }.length
    end

    def paragraph?
      @leaf == :paragraph
    end

    # How a line that continues every container is hidden in the code or
    # HTML block open there, or nil. A blank line ends an HTML block that
    # runs to one, and isn't part of it.
    def continue_leaf(scan)
      case @leaf
      when BlockStarts::Fence then continue_fence(scan)
      when BlockStarts::Html then continue_html(scan)
      when :code then continue_code(scan)
      end
    end

    # Closes every container past the first +count+.
    def close(count)
      @containers = @containers.first(count)
    end

    # Opens +container+ inside the others, which now hold something.
    def push(container)
      fill
      @containers << container
      @leaf = nil
    end

    def fill
      @containers.each { |container| container.filled = true if container.is_a?(Item) }
    end

    # Whether an item with +marker+ takes the place of the item at +index+
    # in the same list.
    def continues_list?(index, marker)
      sibling = @containers[index]
      sibling.is_a?(Item) && sibling.kind == marker.kind
    end

    def depth
      @containers.count { |container| container.is_a?(Item) }
    end

    def quoted?
      @containers.include?(QUOTE)
    end

    def footnote?
      @containers.include?(FOOTNOTE)
    end

    private

    def enter(scan, container)
      case container
      when QUOTE then scan.enter_quote
      when FOOTNOTE then scan.enter_footnote
      else scan.enter_item(container)
      end
    end

    def continue_fence(scan)
      @leaf = nil if @leaf.closed_by?(scan)
      :code
    end

    def continue_html(scan)
      return @leaf = nil if scan.blank? && @leaf.ends_at_blank_line?

      kind = @leaf.kind
      @leaf = nil if @leaf.ended_by?(scan.rest)
      kind
    end

    def continue_code(scan)
      return :code if scan.blank? || scan.indent >= CODE_INDENT

      @leaf = nil
    end
  end
end

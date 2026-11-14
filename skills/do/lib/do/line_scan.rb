# frozen_string_literal: true

module Do
  # One line as BlockReader walks it, from its container markers inwards.
  # Its tabs are expanded to the next multiple of four columns, as
  # CommonMark counts indentation, so that a column is a character of
  # +text+; +raw+ keeps the line as written.
  class LineScan
    TAB_STOP = 4
    MAX_MARKER_INDENT = 3
    QUOTE_MARKER = '>'

    attr_reader :raw, :text, :position

    def initialize(raw)
      @raw = raw
      @text = raw.gsub(/[^\t]*\t/) { |chunk| "#{chunk.chop}#{' ' * (TAB_STOP - ((chunk.length - 1) % TAB_STOP))}" }
      @position = 0
    end

    def first_nonspace
      @text.index(/[^ ]/, @position) || @text.length
    end

    def indent
      first_nonspace - @position
    end

    def blank?
      first_nonspace == @text.length
    end

    # The line from its first character past the position that isn't a space.
    def rest
      @text[first_nonspace..]
    end

    def advance_to(column)
      @position = [column, @text.length].min
    end

    def quote_marker?
      indent <= MAX_MARKER_INDENT && @text[first_nonspace] == QUOTE_MARKER
    end

    # The scan moved past a block quote's marker and one space after it, or
    # nil when the line has none.
    def enter_quote
      return unless quote_marker?

      @position = first_nonspace + 1
      @position += 1 if @text[@position] == ' '
      self
    end

    # The scan moved to +item+'s content when the line continues it, by
    # indentation or as a blank line once the item holds something; or nil.
    def enter_item(item)
      return (self if item.filled) if blank?
      return if first_nonspace < item.column

      @position = item.column
      self
    end
  end
end

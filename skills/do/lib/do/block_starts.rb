# frozen_string_literal: true

require_relative 'line_scan'

module Do
  # How a block starts in CommonMark (0.29, which cmark-gfm follows), read
  # from the first character of a line's content that isn't a space, its
  # indentation already under four columns and its tabs expanded.
  module BlockStarts
    ATX_HEADING = /\A\#{1,6}(?: |\z)/
    SETEXT_UNDERLINE = /\A(?:=+|-+) *\z/
    THEMATIC_BREAK = /\A(?:(?:\* *){3,}|(?:- *){3,}|(?:_ *){3,})\z/
    # A backtick fence's info string holds no backtick.
    OPENING_FENCE = /\A(?<fence>`{3,}(?=[^`]*\z)|~{3,})/
    LIST_MARKER = /\A(?:(?<bullet>[-*+])|(?<number>[0-9]{1,9})(?<delimiter>[.)]))(?= |\z)(?<spaces> *)(?<content>.*)\z/
    # Past five spaces after its marker, an item's content is indented code
    # that starts one space after it.
    CODE_PADDING = 5
    BLOCK_TAGS = %w[
      address article aside base basefont blockquote body caption center col colgroup dd details dialog dir div dl dt
      fieldset figcaption figure footer form frame frameset h1 h2 h3 h4 h5 h6 head header hr html iframe legend li link
      main menu menuitem nav noframes ol optgroup option p param section source summary table tbody td tfoot th thead
      title tr track ul
    ].join('|')
    ATTRIBUTE = /\s+[A-Za-z_:][A-Za-z0-9_.:-]*(?:\s*=\s*(?:[^\s"'=<>`]+|'[^']*'|"[^"]*"))?/
    # A complete open or closing tag alone on its line: HTML block type 7,
    # which can't interrupt a paragraph.
    LONE_TAG = %r{\A(?:<[A-Za-z][A-Za-z0-9-]*#{ATTRIBUTE}*\s*/?>|</[A-Za-z][A-Za-z0-9-]*\s*>) *\z}

    # +kind+ is :comment, :raw for the HTML blocks that run to a closing
    # string, or :html for those that run to a blank line, whose +ending+
    # is nil.
    Html = Struct.new(:kind, :ending) do
      def ends_at_blank_line?
        ending.nil?
      end

      def ended_by?(text)
        !ending.nil? && ending.match?(text)
      end
    end

    HTML_BLOCKS = [
      [/\A<(?:script|pre|style|textarea)(?:[ >]|\z)/i, %r{</(?:script|pre|style|textarea)>}i, :raw],
      [/\A<!--/, /-->/, :comment],
      [/\A<\?/, /\?>/, :raw],
      [/\A<![A-Za-z]/, />/, :raw],
      [/\A<!\[CDATA\[/, /\]\]>/, :raw],
      [%r{\A</?(?:#{BLOCK_TAGS})(?: |/?>|\z)}i, nil, :html]
    ].freeze

    # +width+ is how many times the fence repeats its character.
    Fence = Struct.new(:character, :width) do
      # A closing fence repeats the opening character at least as many
      # times, with only spaces after it.
      def closed_by?(scan)
        scan.indent <= LineScan::MAX_MARKER_INDENT && /\A#{Regexp.escape(character)}{#{width},} *\z/.match?(scan.rest)
      end
    end

    # A leaf block a line starts: +block+ is the leaf left open over later
    # lines, nil for one that ends with its line, and +hidden+ how GitHub
    # shows the line, as BlockReader::Line has it.
    Leaf = Struct.new(:block, :hidden)
    LINE_LEAF = Leaf.new(nil, nil).freeze

    # A list item's marker: +kind+ its bullet or an ordered item's
    # delimiter, which items of one list share, +width+ its characters,
    # +spaces+ those after it, +blank+ when nothing follows them, and
    # +start+ an ordered item's number.
    ListMarker = Struct.new(:kind, :width, :spaces, :blank, :start, keyword_init: true) do
      # The columns from the marker to the item's content.
      def padding
        blank || spaces >= CODE_PADDING ? width + 1 : width + spaces
      end

      # Whether the item may start a list in the middle of a paragraph: it
      # holds something and, if ordered, starts at 1.
      def interrupts_paragraph?
        !blank && (start.nil? || start == 1)
      end
    end

    module_function

    # The Leaf +rest+ starts, if any, +interrupting+ a paragraph or not.
    def leaf(rest, interrupting:)
      fence = fence(rest)
      return Leaf.new(fence, :code) if fence

      html = html(rest, interrupting: interrupting)
      return Leaf.new(html.ended_by?(rest) ? nil : html, html.kind) if html

      LINE_LEAF if line_leaf?(rest, interrupting)
    end

    # A heading or a thematic break, which win over a list item, or a setext
    # underline, which only follows a paragraph, making it a heading.
    def line_leaf?(rest, interrupting)
      ATX_HEADING.match?(rest) || THEMATIC_BREAK.match?(rest) || (interrupting && SETEXT_UNDERLINE.match?(rest))
    end

    def fence(rest)
      fence = rest[OPENING_FENCE, 'fence']
      fence && Fence.new(fence[0], fence.length)
    end

    # The HTML block +rest+ starts, if any; a lone tag only when it isn't
    # +interrupting+ a paragraph.
    def html(rest, interrupting:)
      HTML_BLOCKS.each { |start, ending, kind| return Html.new(kind, ending) if start.match?(rest) }
      Html.new(:html, nil) if !interrupting && LONE_TAG.match?(rest)
    end

    def list_marker(rest)
      match = LIST_MARKER.match(rest)
      return unless match

      marker = match[:bullet] || "#{match[:number]}#{match[:delimiter]}"
      ListMarker.new(kind: match[:bullet] || match[:delimiter], width: marker.length, spaces: match[:spaces].length,
                     blank: match[:content].empty?, start: match[:number]&.then { |number| Integer(number, 10) })
    end
  end
end

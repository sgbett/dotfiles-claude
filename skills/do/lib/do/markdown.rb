# frozen_string_literal: true

module Do
  # Reads Markdown line by line the way GitHub renders it, so a checklist,
  # gate line or heading quoted in a fenced code block is never taken for
  # a real one.
  module Markdown
    # CommonMark: up to three spaces of indentation, then three or more
    # backticks or tildes; a backtick fence's info string holds no backtick.
    OPENING_FENCE = /\A {0,3}(?<fence>`{3,}(?=[^`]*\z)|~{3,})/

    module_function

    # The lines of +text+ outside fenced code blocks, without line endings.
    # A fence left open runs to the end, as GitHub renders it.
    def unfenced_lines(text)
      lines_with_fences(text).reject(&:last).map(&:first)
    end

    # Each line of +text+, without its line ending, paired with whether it
    # belongs to a fenced code block, its fences included.
    def lines_with_fences(text)
      fence = nil
      text.to_s.each_line(chomp: true).map do |line|
        inside = fence
        fence = fence_after(line, fence)
        [line, !(inside || fence).nil?]
      end
    end

    # The fence still open after +line+, given +fence+, the one open before
    # it. A closing fence repeats the opening character at least as many
    # times, with only spaces after it.
    def fence_after(line, fence)
      if fence
        fence unless /\A {0,3}#{Regexp.escape(fence[0])}{#{fence.length},}[ \t]*\z/.match?(line)
      else
        line[OPENING_FENCE, 'fence']
      end
    end

    private_class_method :fence_after
  end
end

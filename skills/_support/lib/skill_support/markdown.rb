# frozen_string_literal: true

module SkillSupport
  # Reads Markdown line by line, telling fenced code blocks apart, so a line
  # quoted in one, such as a heading, is never taken for a real one. Fences
  # are all it knows: reading a checklist as GitHub renders it takes list
  # items and HTML blocks too.
  module Markdown
    # CommonMark: up to three spaces of indentation, then three or more
    # backticks or tildes; a backtick fence's info string holds no backtick.
    OPENING_FENCE = /\A {0,3}(?<fence>`{3,}(?=[^`]*\z)|~{3,})/

    module_function

    # Each line of +text+, without its line ending, paired with whether it
    # belongs to a fenced code block, its fences included. A fence left open
    # runs to the end, as GitHub renders it.
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

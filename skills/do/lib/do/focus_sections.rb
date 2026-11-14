# frozen_string_literal: true

require_relative 'markdown'

module Do
  # The "## Security focus" sections of a Markdown document, each from its
  # heading to the next heading of level one or two, read as GitHub renders
  # it: a heading inside a fenced code block is code.
  module FocusSections
    HEADING = /\A {0,3}##[ \t]+security focus(?:[ \t]+#+)?[ \t]*\z/i
    SECTION_END = /\A {0,3}\#{1,2}(?:[ \t]|\z)/

    module_function

    # Each section's text, its heading included, without trailing blank lines.
    def extract(text)
      sections = []
      open = false
      Markdown.lines_with_fences(text).each do |line, fenced|
        kind = fenced ? nil : heading(line)
        sections << [] if kind == :focus
        open = kind == :focus if kind
        sections.last << line if open
      end
      sections.map { |lines| lines.join("\n").rstrip }
    end

    # :focus for a Security focus heading, :other for any other heading that
    # ends a section, nil for a line that doesn't.
    def heading(line)
      return :focus if HEADING.match?(line)

      :other if SECTION_END.match?(line)
    end

    private_class_method :heading
  end
end

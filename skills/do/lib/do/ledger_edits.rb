# frozen_string_literal: true

module Do
  # The line changes record makes to the ledger's text, each leaving every
  # other byte as it was.
  module LedgerEdits
    LINE_ENDING = /\r?\n\z/

    module_function

    # +body+ with +line+ added at the end as a paragraph of its own: on
    # GitHub, a line straight after a list item would join that item.
    def append(body, line)
      newline = body.include?("\r\n") ? "\r\n" : "\n"
      text = body.empty? || body.end_with?("\n") ? body : "#{body}#{newline}"
      text = "#{text}#{newline}" unless text.empty? || text.lines.last.strip.empty?
      "#{text}#{line}#{newline}"
    end

    # +body+ with each line at +indices+ replaced by +line+, keeping its
    # line ending.
    def replace(body, indices, line)
      lines = body.lines
      indices.each { |index| lines[index] = "#{line}#{lines.fetch(index)[LINE_ENDING]}" }
      lines.join
    end
  end
end

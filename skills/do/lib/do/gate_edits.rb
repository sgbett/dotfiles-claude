# frozen_string_literal: true

require_relative 'gate_file'
require_relative 'gate_state'

module Do
  # A change to the gate file wouldn't read back as asked, as when a code
  # fence left open swallows whatever follows it.
  class UnreadableGateFile < SkillSupport::Error; end

  # The changes `record gate` makes to a GateFile, in its format. Each
  # returns the whole new text, once it reads back with the change, and
  # leaves every line it doesn't change as it was.
  module GateEdits
    # A finding is fenced with more backticks than any run in its text, so
    # that no line of it can close the fence.
    SHORTEST_FENCE = 3
    LINE_ENDING = /\r?\n\z/

    module_function

    # +file+'s text with +finding+, as the white-hat reported it, added as
    # open finding +id+, fenced so that nothing in it reads as a heading or
    # an answer.
    def add(file, id, finding)
      fence = '`' * [SHORTEST_FENCE, finding.scan(/`+/).map(&:length).max.to_i + 1].max
      section = "## #{id}: #{GateState::OPEN}\n\n#{fence}\n#{finding}#{"\n" unless finding.end_with?("\n")}#{fence}\n"
      checked("#{block_end(file.text)}#{section}", id) do |found|
        found.state == GateState::OPEN && found.answer.nil?
      end
    end

    # +file+'s text with the owner's +answer+ to finding +id+ on the line
    # after its first heading.
    def answer(file, id, answer)
      lines = file.text.lines
      index = file.heading_lines(id).fetch(0)
      lines[index] = "#{lines[index]}\n" unless lines[index].end_with?("\n")
      lines.insert(index + 1, "Answer: #{answer}#{lines[index][LINE_ENDING]}")
      checked(lines.join, id) { |found| found.answer == answer }
    end

    # +file+'s text with every heading of finding +id+ giving +state+.
    def mark(file, id, state)
      lines = file.text.lines
      file.heading_lines(id).each { |index| lines[index] = "## #{id}: #{state}#{lines[index][LINE_ENDING]}" }
      checked(lines.join, id) { |found| found.state == state }
    end

    # +text+ ending in a blank line, so that what follows starts a block of
    # its own; empty text stays empty.
    def block_end(text)
      return text if text.empty?

      text = "#{text}\n" unless text.end_with?("\n")
      text.end_with?("\n\n") ? text : "#{text}\n"
    end

    # +text+, once it reads back with finding +id+ as the block expects.
    def checked(text, id)
      found = GateFile.new(text).finding(id)
      raise UnreadableGateFile, "the gate file wouldn't read back with #{id} as written" unless found && yield(found)

      text
    end

    private_class_method :block_end, :checked
  end
end

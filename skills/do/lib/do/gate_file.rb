# frozen_string_literal: true

require_relative 'gate_state'
require_relative 'markdown'
require_relative 'private_file'

module Do
  # The local record of an issue's security gate findings, kept in the
  # repository's common git directory, where no commit or push can carry it:
  # <git common dir>/do/<issue node id>-gate.md. Each finding reads
  #
  #   ## G<k>: <open | fixed | user decided>
  #   Answer: <fix here | advisory>
  #
  #   <the finding as reported>
  #
  # The Answer line is optional and, when present, the first non-blank line
  # after its heading. Headings and Answer lines inside fenced code blocks
  # are finding text. A heading repeated for one G<k> makes one finding,
  # open if any heading says so and advisory if any answer does. Finding
  # text is never read out: until it's fixed, it describes a live flaw.
  # GateEdits makes the text of a change, which .write puts in place.
  class GateFile
    DIRECTORY = 'do'
    SUFFIX = '-gate.md'
    HEADING = /\A## (?<id>G[1-9][0-9]*):(?<state>.*)\z/
    ANSWER = /\AAnswer: (?<answer>fix here|advisory)[ \t]*\z/
    ADVISORY = 'advisory'
    # NOFOLLOW refuses a symlink as the file itself; NONBLOCK stops a FIFO
    # from hanging the open until something writes to it.
    OPEN_FLAGS = File::RDONLY | File::NOFOLLOW | File::NONBLOCK

    Finding = Struct.new(:id, :state, :answer, keyword_init: true)
    # G<k> ids, the ledger and the file taken together: +open+ in either;
    # +partial+, open in the file with no ledger line, so left part-way;
    # +missing+, an open ledger line the file lacks; +advisory+, open and
    # answered advisory.
    Status = Struct.new(:open, :partial, :missing, :advisory, keyword_init: true)

    attr_reader :text

    # Where the gate file of the issue with GraphQL node id +node_id+ lives.
    def self.path(common_directory, node_id)
      directory = File.join(File.realpath(common_directory), DIRECTORY)
      path = File.join(directory, "#{SkillSupport::Identifiers.node_id!(node_id)}#{SUFFIX}")
      raise UnsafeGateFile, "#{path} is outside #{directory}" unless File.dirname(File.expand_path(path)) == directory

      path
    end

    # The gate file at +path+, or an empty one when there is none.
    def self.read(path)
      directory = File.dirname(path)
      raise UnsafeGateFile, "#{directory} is a symlink; refusing to follow it" if File.symlink?(directory)

      File.open(path, OPEN_FLAGS) do |file|
        raise UnsafeGateFile, "#{path} is not a regular file" unless file.stat.file?

        new(file.read.force_encoding(Encoding::UTF_8).scrub)
      end
    rescue Errno::ENOENT
      new('')
    rescue Errno::ELOOP, Errno::EMLINK
      raise UnsafeGateFile, "#{path} is a symlink; refusing to follow it"
    end

    # Puts +text+ in place as the gate file at +path+, a path .path gave: the
    # directory 0700, the file 0600, never through a symlink.
    def self.write(path, text)
      PrivateFile.write(path, text)
    end

    def initialize(text)
      @text = text
      @findings = {}
      @headings = {}
      awaiting_answer = nil
      Markdown.lines_with_fences(text).each_with_index do |(line, fenced), index|
        awaiting_answer = read_line(line, index, awaiting_answer) unless fenced
      end
    end

    def findings
      @findings.values
    end

    # The finding +id+ names, or nil.
    def finding(id)
      @findings[id]
    end

    # The indices among the text's lines of finding +id+'s headings.
    def heading_lines(id)
      @headings.fetch(id, []).map(&:first)
    end

    # Whether every heading of finding +id+ gives +state+.
    def marked?(id, state)
      @headings.fetch(id, []).all? { |_index, heading_state| heading_state == state }
    end

    # The lowest G<k> that neither this file nor the ledger, whose G<k> ids
    # are +ledger_ids+, uses.
    def next_id(ledger_ids)
      used = @findings.keys | ledger_ids
      number = 1
      number += 1 while used.include?("G#{number}")
      "G#{number}"
    end

    # +ledger_gates+ are the ledger's Gate lines.
    def status(ledger_gates)
      ledger_open = open_ids(ledger_gates)
      file_open = open_ids(findings)
      open = ordered(file_open | ledger_open)
      Status.new(open: open, partial: ordered(file_open - ledger_gates.map(&:id)),
                 missing: ordered(ledger_open - @findings.keys), advisory: open.select { |id| advisory?(id) })
    end

    private

    # Reads one line outside a fence, given the finding still awaiting its
    # answer line, and returns the one awaiting it after.
    def read_line(line, index, awaiting_answer)
      heading = HEADING.match(line)
      return note_heading(heading[:id], GateState.parse(heading[:state]), index) if heading
      return awaiting_answer if awaiting_answer.nil? || line.strip.empty?

      note_answer(awaiting_answer, ANSWER.match(line))
      nil
    end

    def open_ids(entries)
      entries.select { |entry| entry.state == GateState::OPEN }.map(&:id)
    end

    def advisory?(id)
      @findings.key?(id) && @findings[id].answer == ADVISORY
    end

    def note_heading(id, state, index)
      (@headings[id] ||= []) << [index, state]
      finding = @findings[id] ||= Finding.new(id: id, state: state)
      finding.state = state if state == GateState::OPEN
      finding
    end

    def note_answer(finding, answer)
      return if answer.nil? || finding.answer == ADVISORY

      finding.answer = answer[:answer]
    end

    def ordered(ids)
      ids.uniq.sort_by { |id| Integer(id.delete_prefix('G'), 10) }
    end
  end
end

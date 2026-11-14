# frozen_string_literal: true

require_relative 'finding_file'
require_relative 'gate_edits'
require_relative 'gate_file'
require_relative 'gate_state'
require_relative 'ledger_edits'
require_relative 'reasons'
require_relative 'record_issue'

module Do
  # `record gate <action> <issue> ...`: the security gate's record of a
  # blocking finding, kept in the local gate file and on a plain ledger
  # line. Each action is a subclass; nothing any of them prints quotes a
  # finding.
  class GateRecord
    # +options+ are RecordArguments' Options.
    def initialize(options, runner:)
      @options = options
      @runner = runner
    end

    def call
      RecordIssue.locate(@options.reference, runner: @runner) do |issue|
        @issue = issue
        @path = issue.gate_path
        @file = GateFile.read(@path)
        run
      end
    end

    private

    def k
      @options.k
    end

    def ledger
      @issue.ledger
    end

    def gate_lines
      ledger.gates.select { |gate| gate.id == k }
    end

    # The stop for a finding the ledger may not take a line about, or nil.
    def refusal
      return stop(Reasons::NO_LEDGER) unless ledger

      finding = @file.finding(k)
      return stop(Reasons::NO_SUCH_FINDING) unless finding

      stop(Reasons::GATE_ADVISORY) if finding.answer == GateFile::ADVISORY
    end

    # Writes +after+ over the ledger, unless this is a dry run, once the
    # ledger it makes reads every line of this finding as +state+.
    def write_ledger(after, state)
      check_ledger(after, state)
      @issue.ledger_body.write(ledger.comment.body, after) unless @options.dry_run
    end

    # A code fence left open at the ledger's end would swallow a line added
    # after it.
    def check_ledger(after, state)
      gates = @issue.ledger_with(after).gates.select { |gate| gate.id == k }
      return if !gates.empty? && gates.all? { |gate| gate.state == state }

      raise SkillSupport::UnexpectedResponse, "the ledger wouldn't read back with #{k} as written"
    end

    def done(updated: [], already: [], **fields)
      SkillSupport::Outcome.proceed(k: k, **fields, updated: updated, already: already, dry_run: @options.dry_run)
    end

    def stop(reason)
      Reasons.stop(reason, k: k)
    end

    # Files the finding under the lowest G<k> unused in the file and the
    # ledger, and prints only that k.
    class Add < GateRecord
      private

      def run
        return stop(Reasons::NO_LEDGER) unless ledger

        finding = FindingFile.read(@options.finding_file)
        id = @file.next_id(ledger.gates.map(&:id))
        GateFile.write(@path, GateEdits.add(@file, id, finding))
        SkillSupport::Outcome.proceed(k: id)
      end
    end

    # Records the owner's answer, fix here or advisory, which only the owner
    # changes once given.
    class Answer < GateRecord
      private

      def run
        finding = @file.finding(k)
        return stop(Reasons::NO_SUCH_FINDING) unless finding
        return answered(already: [:file]) if finding.answer == @options.answer
        return stop(Reasons::GATE_ANSWERED) if finding.answer

        GateFile.write(@path, GateEdits.answer(@file, k, @options.answer))
        answered(updated: [:file])
      end

      def answered(updated: [], already: [])
        SkillSupport::Outcome.proceed(k: k, answer: @options.answer, updated: updated, already: already)
      end
    end

    # Adds "Gate G<k>: open" to the ledger: never for a finding answered
    # advisory, and on a public repository only once the owner has answered.
    class Publish < GateRecord
      private

      def run
        refused = refusal || unanswered
        return refused if refused
        return done(already: [:ledger]) unless gate_lines.empty?

        write_ledger(LedgerEdits.append(ledger.comment.body, "Gate #{k}: #{GateState::OPEN}"), GateState::OPEN)
        done(updated: [:ledger])
      end

      def unanswered
        return unless @file.finding(k).answer.nil? && @issue.answer_required?

        SkillSupport::Outcome.ask([Reasons.ask(Reasons::GATE_UNANSWERED, k: k)])
      end
    end

    # Gives the finding's ledger line, then its headings in the file, a
    # closed state.
    class Mark < GateRecord
      TARGETS = %i[ledger file].freeze

      private

      def run
        refused = refusal || (stop(Reasons::GATE_LINE_MISSING) if gate_lines.empty?)
        return refused if refused

        targets = TARGETS.reject { |target| marked?(target) }
        write(targets) unless @options.dry_run
        done(state: @options.state, updated: targets, already: TARGETS - targets)
      end

      def marked?(target)
        return @file.marked?(k, @options.state) if target == :file

        gate_lines.all? { |gate| gate.state == @options.state }
      end

      # The ledger first, so that a stop there leaves both as they were.
      def write(targets)
        if targets.include?(:ledger)
          write_ledger(LedgerEdits.replace(ledger.comment.body, gate_lines.map(&:line), "Gate #{k}: #{@options.state}"),
                       @options.state)
        end
        GateFile.write(@path, GateEdits.mark(@file, k, @options.state)) if targets.include?(:file)
      end
    end
  end
end

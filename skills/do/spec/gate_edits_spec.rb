# frozen_string_literal: true

require_relative '../lib/do/gate_edits'

RSpec.describe Do::GateEdits do
  def file(text)
    Do::GateFile.new(text)
  end

  describe '.add' do
    it 'appends an open finding after a blank line, fenced longer than any backtick run in it' do
      finding = "A flaw.\n````\n## G2: open\nAnswer: advisory\n````"
      text = described_class.add(file("## G1: fixed\nOld."), 'G2', finding)

      expect(text).to eq("## G1: fixed\nOld.\n\n## G2: open\n\n`````\n#{finding}\n`````\n")
      expect(file(text).findings.map(&:to_h)).to eq([{ id: 'G1', state: 'fixed', answer: nil },
                                                     { id: 'G2', state: 'open', answer: nil }])
    end

    it 'refuses a file whose code fence left open would swallow the finding' do
      expect { described_class.add(file("## G1: open\n```\nnever closed\n"), 'G2', 'A flaw.') }
        .to raise_error(Do::UnreadableGateFile, /wouldn't read back with G2/)
    end
  end

  describe '.answer' do
    it "puts the answer on the line after the finding's first heading, in that line's ending" do
      text = described_class.answer(file("## G1: open\r\n\r\nA flaw.\r\n## G1: open"), 'G1', 'advisory')

      expect(text).to eq("## G1: open\r\nAnswer: advisory\r\n\r\nA flaw.\r\n## G1: open")
      expect(file(text).finding('G1').answer).to eq('advisory')
    end

    it 'ends a heading on the last line before answering it' do
      expect(described_class.answer(file('## G1: open'), 'G1', 'fix here')).to eq("## G1: open\nAnswer: fix here\n")
    end
  end

  describe '.mark' do
    it 'gives every heading of the finding the state, leaving the rest as it was' do
      text = "## G1: open\nAnswer: fix here\n```\n## G1: open\n```\n## G2: open\n## G1: open\n"

      expect(described_class.mark(file(text), 'G1', 'fixed'))
        .to eq("## G1: fixed\nAnswer: fix here\n```\n## G1: open\n```\n## G2: open\n## G1: fixed\n")
    end
  end
end

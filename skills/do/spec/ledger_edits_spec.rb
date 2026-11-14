# frozen_string_literal: true

require_relative '../lib/do/ledger_edits'

RSpec.describe Do::LedgerEdits do
  describe '.append' do
    it 'adds the line as a paragraph of its own, whatever the body ends with' do
      bodies = ['- [ ] L1', "- [ ] L1\n", "- [ ] L1\n\n", '']

      expect(bodies.map { |body| described_class.append(body, 'Gate G1: open') })
        .to eq(["- [ ] L1\n\nGate G1: open\n", "- [ ] L1\n\nGate G1: open\n", "- [ ] L1\n\nGate G1: open\n",
                "Gate G1: open\n"])
    end

    it "keeps to the body's own line endings" do
      expect(described_class.append("- [ ] L1\r\nGate G1: open", 'Gate G2: open'))
        .to eq("- [ ] L1\r\nGate G1: open\r\n\r\nGate G2: open\r\n")
    end
  end

  describe '.replace' do
    it 'replaces whole lines, keeping each line ending, and nothing else' do
      expect(described_class.replace("a\r\nGate G1: open\r\nb\nGate G1: open", [1, 3], 'Gate G1: fixed'))
        .to eq("a\r\nGate G1: fixed\r\nb\nGate G1: fixed")
    end
  end
end

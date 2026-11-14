# frozen_string_literal: true

require_relative '../lib/do/checklist'

RSpec.describe Do::Checklist do
  let(:body) do
    <<~MARKDOWN
      Intro
      - [ ] One
        - [ ] nested detail
      ```
      - [ ] Quoted
      ```
      * [X] Two
      + [x] Three
      > - [ ] quoted
      - [ ]Four
    MARKDOWN
  end

  describe '.boxes' do
    it 'reads unindented boxes outside code fences, with their place among the boxes and the lines' do
      expect(described_class.boxes(body).map { |box| [box.position, box.line, box.checked, box.text] })
        .to eq([[1, 1, false, 'One'], [2, 6, true, 'Two'], [3, 7, true, 'Three']])
    end
  end

  describe '.at' do
    it 'finds the box at each position, and lists the positions no box holds' do
      found, missing = described_class.at(described_class.boxes(body), [3, 1, 4])

      expect([found.map(&:text), missing]).to eq([%w[Three One], [4]])
    end
  end

  describe '.tick' do
    it 'turns "[ ]" into "[x]" on the lines given and leaves every other byte as it was' do
      text = "- [ ] One\r\n* [ ] Two\r\n- [ ] Three"

      expect(described_class.tick(text, [1, 2])).to eq("- [ ] One\r\n* [x] Two\r\n- [x] Three")
    end

    it 'refuses a line that holds no unticked box' do
      expect { described_class.tick("- [x] One\nText\n", [0]) }.to raise_error(ArgumentError, /no unticked box/)
      expect { described_class.tick("- [x] One\nText\n", [1]) }.to raise_error(ArgumentError, /no unticked box/)
    end
  end
end

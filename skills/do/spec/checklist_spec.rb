# frozen_string_literal: true

require_relative '../lib/do/checklist'

# The top-level boxes of a body as GitHub renders them, which positions and
# ledger ids name, and the lines that read like boxes Checklist can't place.
RSpec.describe Do::Checklist do
  # Each box of +body+ as [position, line, mark, checked, text].
  def boxes(body)
    described_class.boxes(body, target: :issue_body).map do |box|
      box.to_h.values_at(:position, :line, :mark, :checked, :text)
    end
  end

  # The lines (from 1) that make +body+ ambiguous, none when it isn't.
  def ambiguous(body)
    described_class.boxes(body, target: :ledger)
    []
  rescue Do::AmbiguousCheckbox => e
    expect(e.target).to eq(:ledger)
    e.lines
  end

  describe 'the boxes GitHub renders at the top level' do
    it 'reads a list item of any marker, indented up to three spaces, then a box, then a space or the end' do
      body = "- [ ] One\n* [x] Two\n+ [X] Three\n1. [ ] Four\n1) [ ] Five\n - [ ] Six\n  * [ ]\n   +  [ ]\tSeven\n"

      expect(boxes(body)).to eq([[1, 0, 3, false, 'One'], [2, 1, 3, true, 'Two'], [3, 2, 3, true, 'Three'],
                                 [4, 3, 4, false, 'Four'], [5, 4, 4, false, 'Five'], [6, 5, 4, false, 'Six'],
                                 [7, 6, 5, false, ''], [8, 7, 7, false, 'Seven']])
    end

    it 'leaves out a box nested in another item, however indented, and takes one less indented than its content' do
      body = "- [ ] One\n  - [ ] detail\n\n  - [ ] detail after a blank\n   * [ ] still inside\n - [ ] Two\n\n" \
             "10. [ ] Ten\n   - [ ] beside Ten, less indented than its content\n     - [ ] inside that\n"

      expect(boxes(body).map { |box| box.values_at(0, 4) })
        .to eq([[1, 'One'], [2, 'Two'], [3, 'Ten'], [4, 'beside Ten, less indented than its content']])
    end

    it 'leaves out boxes in fenced and indented code, a fence in an item ending with the item' do
      body = "```\n- [ ] backticks\n```\n~~~~\n- [ ] tildes\n~~~~\n- [ ] One\n  ```\n  - [ ] in the item's fence\n" \
             "- [ ] Two\n\nText\n\n    - [ ] indented code\n"

      expect(boxes(body).map(&:last)).to eq(%w[One Two])
    end

    it 'leaves out boxes in HTML comments and HTML that runs to a closing string, but not after an inline comment' do
      body = "<!--\n- [ ] in a comment\n-->\n<!-- - [ ] one line -->\n- [ ] One\n  <!-- - [ ] in the item\n  -->\n" \
             "<pre>\n\n- [ ] raw\n</pre>\nText <!-- not an HTML block\n- [ ] Two\n-->\n"

      expect(boxes(body).map(&:last)).to eq(%w[One Two])
    end

    it 'leaves out boxes in a block quote, and takes an item after one' do
      expect(boxes("> - [ ] quoted\n> [ ] quoted too\n- [ ] One\n> - [ ] again\n  - [ ] Two\n").map(&:last))
        .to eq(%w[One Two])
    end

    it 'reads an ordered list GitHub starts after a paragraph only from 1, and after a blank line from any number' do
      expect(boxes("Intro\n1. [ ] One\n2. [ ] Two\n\n3. [ ] Three\n").map(&:last)).to eq(%w[One Two Three])
    end

    it 'reads items GitHub closes, after a thematic break, a heading or an empty item and a blank line' do
      body = "- [ ] One\n***\n  - [ ] after a break\n# Heading\n  - [ ] after a heading\n-\n\n  - [ ] after a blank\n"

      expect(boxes(body).map(&:last)).to eq(['One', 'after a break', 'after a heading', 'after a blank'])
    end

    it 'takes CRLF line endings as one, and is empty for a body with no boxes' do
      expect([boxes("- [ ] One\r\n- [x] Two\r\n").length, boxes("No boxes.\n")]).to eq([2, []])
    end
  end

  describe 'a line that reads like a box Checklist cannot place' do
    it 'is one with no list marker, a tab or odd spacing, or no box GitHub renders' do
      body = "[ ] no marker\n-\t[ ] tab after the marker\n- [\t] tab inside\n-     [ ] five spaces\n-[ ] no space\n" \
             "- [ ]x no space after\n- [] empty\n- [x](https://example.com) a link\n"

      expect(ambiguous(body)).to eq((1..8).to_a)
    end

    it 'is one with no marker inside a top-level item, lazily or indented, or on the line after an empty item' do
      expect(ambiguous("- [ ] One\n[ ] lazy\n  [ ] continued\n-\n  [ ] after an empty item\n")).to eq([2, 3, 5])
    end

    it 'is one in HTML that runs to a blank line, which GitHub may not render as Markdown' do
      expect(ambiguous("<details>\n- [ ] raw HTML\n</details>\n\n<span>\n- [ ] after a lone tag\n")).to eq([2, 6])
    end

    it "is an ordered item GitHub doesn't start after a paragraph, or that starts a new list after a lazy line" do
      expect(ambiguous("Intro\n2. [ ] Two\n\n- [ ] One\n2. [ ] a new list\n")).to eq([2, 5])
    end

    it 'is a carriage return GitHub reads as a line break' do
      expect(ambiguous("- [ ] One\rText\n- [ ] Two\n")).to eq([1])
    end

    it 'is none in a nested item, a quote or code, where no top-level box can be' do
      body = "- [ ] One\n  - [ ]x nested\n\t- [ ] tab-indented detail\n  - b\n  2. [ ] nested, after a lazy line\n" \
             "> [ ] quoted\n```\n[ ] fenced\n```\n"

      expect(ambiguous(body)).to eq([])
    end
  end

  describe '.at' do
    it 'finds the box at each position, and lists the positions no box holds' do
      found, missing = described_class.at(described_class.boxes("- [ ] One\n- [ ] Two\n- [x] Three\n", target: :ledger),
                                          [3, 1, 4])

      expect([found.map(&:text), missing]).to eq([%w[Three One], [4]])
    end
  end

  describe '.tick' do
    it 'turns "[ ]" into "[x]" at each box\'s mark and leaves every other byte as it was' do
      text = "- [ ] One\r\n* [ ] Two\r\n 1. [ ] Three"
      boxes = described_class.boxes(text, target: :issue_body)

      expect(described_class.tick(text, boxes.drop(1))).to eq("- [ ] One\r\n* [x] Two\r\n 1. [x] Three")
    end

    it 'refuses a box whose line holds no unticked box at its mark' do
      ticked = described_class::Box.new(line: 0, mark: 3)
      moved = described_class::Box.new(line: 1, mark: 3)

      [ticked, moved].each do |box|
        expect { described_class.tick("- [x] One\nText\n", [box]) }.to raise_error(ArgumentError, /no unticked box/)
      end
    end
  end
end

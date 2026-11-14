# frozen_string_literal: true

require_relative '../lib/do/block_reader'

RSpec.describe Do::BlockReader do
  def read(body, *fields)
    described_class.read(body).map { |line| line.to_h.values_at(*fields) }
  end

  it 'says how GitHub hides each line: code, a comment, HTML to a closing string, or HTML to a blank line' do
    body = "```\nfenced\n```\n\n    indented\n<!-- a\ncomment -->\n<pre>\n\nraw\n</pre>\n<div>\nhtml\n\ntext\n"

    expect(read(body, :hidden)).to eq([[:code], [:code], [:code], [nil], [:code], [:comment], [:comment], [:raw],
                                       [:raw], [:raw], [:raw], [:html], [:html], [nil], [nil]])
  end

  it 'gives each line the list items that hold it and whether a quote does, a lazy line keeping them open' do
    body = "- a\n  - b\nlazy\n> - c\nd\n"

    expect(read(body, :depth, :quoted)).to eq([[1, false], [2, false], [2, false], [1, true], [1, true]])
  end

  it "gives a top-level task item's mark as an offset in the line as written, and its text" do
    lines = described_class.read("- [ ] One\n\n 12) [X]\tTwo\n- [x]\n")

    expect(lines.map { |line| [line.task&.to_h, line.doubtful] })
      .to eq([[{ mark: 3, checked: false, text: 'One' }, false], [nil, false],
              [{ mark: 6, checked: true, text: 'Two' }, false], [{ mark: 3, checked: true, text: '' }, false]])
  end

  it 'counts a tab to the next multiple of four columns, and doubts a top-level item with one before its box' do
    lines = described_class.read("- [ ] One\n\t- [ ] nested\n-\t[ ] tabbed\n")

    expect(lines.map { |line| [line.depth, line.task&.mark, line.doubtful] })
      .to eq([[1, 3, false], [2, nil, false], [1, nil, true]])
  end
end

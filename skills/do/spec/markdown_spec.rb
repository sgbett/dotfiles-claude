# frozen_string_literal: true

require_relative '../lib/do/markdown'

RSpec.describe Do::Markdown do
  def unfenced(text)
    described_class.unfenced_lines(text)
  end

  it 'returns every line without its line ending, CRLF included' do
    expect(unfenced("- [ ] a\r\nGate G1: open\n\nlast")).to eq(['- [ ] a', 'Gate G1: open', '', 'last'])
  end

  it 'drops backtick and tilde fences with all they hold' do
    text = "before\n```markdown\n- [ ] quoted\n```\nbetween\n~~~\nGate G1: open\n~~~\nafter\n"

    expect(unfenced(text)).to eq(%w[before between after])
  end

  it 'closes a fence only with the same character, at least as long, and nothing after it' do
    text = "````\n```\n~~~~\n```` trailing\n- [ ] still quoted\n`````  \nout\n"

    expect(unfenced(text)).to eq(['out'])
  end

  it 'allows up to three spaces of indentation on a fence' do
    expect(unfenced("   ```\nin\n   ```\nout\n    ```\nindented code, not a fence\n"))
      .to eq(['out', '    ```', 'indented code, not a fence'])
  end

  it "doesn't take inline code for a fence" do
    expect(unfenced("``` `inline` ```\nstill text\n")).to eq(['``` `inline` ```', 'still text'])
  end

  it 'lets a fence left open run to the end' do
    expect(unfenced("text\n```\n- [ ] never closed\n")).to eq(['text'])
  end

  it 'pairs every line with whether a fenced code block holds it, its fences included' do
    expect(described_class.lines_with_fences("a\n```\nb\n```\nc\n~~~\nd"))
      .to eq([['a', false], ['```', true], ['b', true], ['```', true], ['c', false], ['~~~', true], ['d', true]])
  end
end

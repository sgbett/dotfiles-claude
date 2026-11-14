# frozen_string_literal: true

require_relative '../lib/do/checklist'

# Checklist against GitHub's own renders: each spec/fixtures/markdown/<name>.md
# is a body sent to `gh api markdown -f mode=gfm`, and <name>.html what
# GitHub returned (spec/fixtures/README.md). The issue body's boxes are the
# checkboxes GitHub rendered, in order; where GitHub's checkboxes depend on
# what Checklist doesn't model, it names the lines as ambiguous instead.
RSpec.describe "Do::Checklist against GitHub's renders" do
  # Each checkbox GitHub rendered, as [checked, text after it].
  def rendered(name)
    fixture("markdown/#{name}.html").scan(/<input type="checkbox"([^>]*)>([^<\n]*)/).map do |attributes, text|
      [attributes.include?('checked=""'), text.strip]
    end
  end

  # The issue body's boxes as [checked, text], and the ambiguous lines.
  def read(name, target: :issue_body)
    reading = Do::Checklist.scan(fixture("markdown/#{name}.md"), target: target)
    [reading.boxes.map { |box| [box.checked, box.text] }, reading.ambiguous]
  end

  # The line (from 1) each checkbox GitHub rendered sits on, found by the
  # text after it, which ends its line. GitHub writes a vertical tab as
  # U+FFFD.
  def rendered_lines(name)
    lines = fixture("markdown/#{name}.md").lines.map(&:chomp)
    rendered(name).map do |_checked, text|
      label = text.sub(/\A\p{Space}+/, '').tr("\uFFFD", "\v")
      lines.index { |line| line.end_with?(label) } + 1
    end
  end

  it 'counts nested, quoted and ordered boxes in the order GitHub renders them' do
    expect(read('lists')).to eq([rendered('lists'), []])
    expect(rendered('lists').length).to eq(17)
  end

  it 'takes only the top-level boxes of a ledger' do
    expect(read('lists', target: :ledger).first.map(&:last))
      .to eq(['One', 'Two', 'First, interrupting the paragraph', 'Second', 'A new list, by its delimiter',
              'Seventh, after a blank line'])
  end

  it 'reads from after a byte order mark, and past "<!x", but not into the HTML block "<!X" opens' do
    expect(read('html-and-bom')).to eq([rendered('html-and-bom'), []])
  end

  it "names a footnote's boxes as ambiguous: GitHub renders them after the body, or not at all unreferenced" do
    expect(rendered('footnotes'))
      .to eq([[false, 'After the footnotes'], [false, 'A box in a footnote'], [true, 'Another, continued']])
    expect(read('footnotes')).to eq([[[false, 'After the footnotes']], [3, 4, 6]])
  end

  it 'names as ambiguous a box with nothing after it, and one whose paragraph becomes a heading or a table' do
    expect(rendered('not-boxes')).to eq([[false, 'A box'], [false, ''], [false, 'Nested under an empty box']])
    expect(read('not-boxes')).to eq([[[false, 'A box'], [false, 'Nested under an empty box']], [1, 2, 4, 10]])
  end

  it 'names as ambiguous each box GitHub finds behind an escape, a reference, a non-ASCII space or a form feed' do
    boxes, ambiguous = read('encoded')
    lines = rendered_lines('encoded')

    expect(boxes).to eq([[false, 'A box']])
    expect(lines - ambiguous).to eq([34])
  end

  it 'names as ambiguous a line with a vertical tab, though GitHub renders no box there, but no link or word' do
    ambiguous = read('encoded').last

    expect(ambiguous - rendered_lines('encoded')).to eq([26, 27, 30])
    expect(ambiguous & (35..37).to_a).to eq([])
  end
end

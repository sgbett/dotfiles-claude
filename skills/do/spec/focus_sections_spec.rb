# frozen_string_literal: true

require_relative '../lib/do/focus_sections'

RSpec.describe Do::FocusSections do
  def extract(text)
    described_class.extract(text)
  end

  it 'takes a section from its heading to the next heading of level two, without trailing blank lines' do
    text = "# Project\n\nIntro.\n\n## Security focus\n\n- Tokens.\n- Webhooks.\n\n\n## Code Style\n\nPlain.\n"

    expect(extract(text)).to eq(["## Security focus\n\n- Tokens.\n- Webhooks."])
  end

  it 'keeps subheadings inside the section, and ends it at a heading of level one or the end' do
    text = "## Security focus\n### Keys\nRotate.\n# Appendix\nNot focus.\n## Security focus\nLast.\n"

    expect(extract(text)).to eq(["## Security focus\n### Keys\nRotate.", "## Security focus\nLast."])
  end

  it 'reads the heading as GitHub does: any case, up to three spaces, closing hashes' do
    ['## SECURITY FOCUS', '   ## Security focus', '## Security focus ##', "##\tSecurity focus"].each do |heading|
      expect(extract("#{heading}\nText.\n")).to eq(["#{heading}\nText."]), heading
    end
  end

  it 'takes no other heading for the section' do
    ['### Security focus', '## Security focus areas', '    ## Security focus', '#Security focus', 'Security focus']
      .each do |heading|
        expect(extract("#{heading}\nText.\n")).to eq([]), heading
      end
  end

  it 'takes a heading inside a fenced code block for code, and keeps fenced lines within a section' do
    text = "```\n## Security focus\nquoted\n```\n## Security focus\nBefore.\n~~~\n## Not an end\n~~~\nAfter.\n## Next\n"

    expect(extract(text)).to eq(["## Security focus\nBefore.\n~~~\n## Not an end\n~~~\nAfter."])
  end

  it 'finds nothing in a document without one, or in nothing' do
    expect([extract("# Project\n\n## Code Style\n"), extract('')]).to eq([[], []])
  end
end

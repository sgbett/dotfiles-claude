# frozen_string_literal: true

require_relative '../lib/repo_consistency/tier_line'

RSpec.describe RepoConsistency::TierLine do
  def read(text)
    described_class.read(text).to_h.values_at(:word, :difference)
  end

  it 'reads the word and the difference after the semicolon, stripped, anywhere in a line' do
    expect(read("# Project\n\nGit tier: protected\n")).to eq(['protected', nil])
    expect(read("Rules: Git tier: personal; issue-tracked work goes by PR  \n"))
      .to eq(['personal', 'issue-tracked work goes by PR'])
    expect(read("Git tier: personal ;spaced\n")).to eq(%w[personal spaced])
  end

  it 'reads collaborative, the retired word, so that it can be reported' do
    expect(read("Git tier: collaborative; releases by tag\n")).to eq(['collaborative', 'releases by tag'])
  end

  it 'ends a difference quoted in backticks at the closing one, so prose after it is not taken' do
    text = "- **Tier:** `Git tier: personal; issue-tracked work goes by PR` (small edits straight to master).\n"

    expect(read(text)).to eq(['personal', 'issue-tracked work goes by PR'])
  end

  it 'takes the first line when there are several, and an empty difference as none' do
    expect(read("Git tier: protected;\nGit tier: personal; later\n")).to eq(['protected', nil])
  end

  it 'finds no line without the literal, for a missing file, and for a word it does not know' do
    expect(read("# Project\n\nGit tier: shared\n")).to eq([nil, nil])
    expect(read(nil)).to eq([nil, nil])
    expect(read('')).to eq([nil, nil])
  end

  it 'does not let a difference run on to the next line' do
    expect(read("Git tier: personal;\nnot the difference\n")).to eq(['personal', nil])
  end
end

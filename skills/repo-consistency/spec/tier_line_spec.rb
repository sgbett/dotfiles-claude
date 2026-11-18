# frozen_string_literal: true

require_relative '../lib/repo_consistency/tier_line'

RSpec.describe RepoConsistency::TierLine do
  def read(text)
    described_class.read(text).to_h.values_at(:tier, :difference)
  end

  it 'reads the tier and the difference after the semicolon, stripped, anywhere in a line' do
    expect(read("# Project\n\nGit tier: collaborative\n")).to eq(['collaborative', nil])
    expect(read("Rules: Git tier: personal; issue-tracked work goes by PR  \n"))
      .to eq(['personal', 'issue-tracked work goes by PR'])
    expect(read("Git tier: personal ;spaced\n")).to eq(%w[personal spaced])
  end

  it 'ends a difference quoted in backticks at the closing one, so prose after it is not taken' do
    text = "- **Tier:** `Git tier: personal; issue-tracked work goes by PR` (small edits straight to master).\n"

    expect(read(text)).to eq(['personal', 'issue-tracked work goes by PR'])
  end

  it 'takes the first declaration when there are several, and an empty difference as none' do
    expect(read("Git tier: collaborative;\nGit tier: personal; later\n")).to eq(['collaborative', nil])
  end

  it 'is undeclared without the literal, for a missing file, and for a tier it does not know' do
    expect(read("# Project\n\nGit tier: shared\n")).to eq(['undeclared', nil])
    expect(read(nil)).to eq(['undeclared', nil])
    expect(read('')).to eq(['undeclared', nil])
  end

  it 'does not let a difference run on to the next line' do
    expect(read("Git tier: personal;\nnot the difference\n")).to eq(['personal', nil])
  end
end

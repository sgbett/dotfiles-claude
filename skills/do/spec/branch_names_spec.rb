# frozen_string_literal: true

require_relative '../lib/do/branch_names'

RSpec.describe Do::BranchNames do
  let(:names) { ['feat/24-work', 'release_1.2+x', 'project/#12_x/master', "feat/24-x'y", 'feat/24-$(x)', 'feat/24 x'] }

  it 'takes as usable only a name of letters, digits and . _ / + # -, as every script takes one' do
    expect(described_class.usable(names)).to eq(['feat/24-work', 'release_1.2+x', 'project/#12_x/master'])
  end

  it 'lists every other name, skipping none given' do
    expect(described_class.unusable([nil, *names])).to eq(["feat/24-x'y", 'feat/24-$(x)', 'feat/24 x'])
  end
end

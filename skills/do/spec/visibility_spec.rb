# frozen_string_literal: true

require_relative '../lib/do/visibility'
require_relative 'support/records'

RSpec.describe Do::Visibility do
  include Do::Testing::Records

  let(:private_home) { repository(Do::Testing::Records::HOME, visibility: 'PRIVATE') }

  def nameable?(name, visibility)
    described_class.nameable?(repository(name, visibility: visibility), private_home)
  end

  it 'names this repository, whatever its visibility and the case it is written in' do
    expect([nameable?('example-owner/example-repo', 'PRIVATE'), nameable?('EXAMPLE-OWNER/example-REPO', 'INTERNAL')])
      .to eq([true, true])
  end

  it 'names a public repository elsewhere' do
    expect(nameable?('example-owner/upstream', 'PUBLIC')).to be(true)
  end

  it "doesn't name a private, internal or unknown repository elsewhere" do
    expect(['PRIVATE', 'INTERNAL', 'public', nil].map { |visibility| nameable?('example-owner/upstream', visibility) })
      .to eq([false, false, false, false])
  end
end

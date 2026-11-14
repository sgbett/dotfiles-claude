# frozen_string_literal: true

require_relative '../lib/copilot_check/reasons'

RSpec.describe CopilotCheck::Reasons do
  it "is promote-check's whole enum of stops, apart from the reasons its verdict holds for" do
    expect(described_class::PROMOTE_CHECK)
      .to eq(%i[copilot_id_changed copilot_unrecognised threads_overflow head_changed head_unreadable])
    expect(described_class::HOLD & described_class::PROMOTE_CHECK).to be_empty
  end

  it 'gives every reason, and only those, a constant message' do
    expect(described_class::MESSAGES.keys).to match_array(described_class::PROMOTE_CHECK + described_class::HOLD)
    expect(described_class::MESSAGES.values).to all(be_frozen.and(be_a(String)))
  end

  it "tells the lead to undo the ready on either of verify's stops" do
    %i[head_changed head_unreadable].each do |reason|
      expect(described_class::MESSAGES[reason]).to include('Run gh pr ready --undo'), reason.to_s
    end
  end

  it 'builds stops the contract accepts, and refuses to hold for anything but a HOLD reason' do
    expect([described_class.stop(:threads_overflow).exit_code, described_class.hold(:no_checks)])
      .to eq([2, { reason: 'no_checks', message: 'No check has run on the head.' }])
    expect { described_class.hold(:threads_overflow) }.to raise_error(ArgumentError)
  end
end

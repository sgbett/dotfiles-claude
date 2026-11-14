# frozen_string_literal: true

require_relative '../lib/copilot_check/reasons'

RSpec.describe CopilotCheck::Reasons do
  it "is each script's whole enum of stops and asks, apart from the reasons promote-check's verdict holds for" do
    expect(described_class::SETUP).to eq(%i[not_a_pull_request_number fork_pull_request copilot_id_changed])
    expect(described_class::THREADS).to eq(%i[copilot_id_changed copilot_unrecognised threads_overflow])
    expect(described_class::REREVIEW).to eq(%i[copilot_id_changed copilot_timeout])
    expect(described_class::PROMOTE_CHECK)
      .to eq(%i[copilot_id_changed copilot_unrecognised threads_overflow head_changed head_unreadable])
    expect(described_class::HOLD & described_class::ALL).to be_empty
  end

  it 'gives every reason, and only those, a constant message' do
    expect(described_class::MESSAGES.keys).to match_array(described_class::ALL + described_class::HOLD)
    expect(described_class::MESSAGES.values).to all(be_frozen.and(be_a(String)))
  end

  it "tells the lead to undo the ready on either of verify's stops" do
    %i[head_changed head_unreadable].each do |reason|
      expect(described_class::MESSAGES[reason]).to include('Run gh pr ready --undo'), reason.to_s
    end
  end

  it 'builds stops and asks the contract accepts, and refuses to hold for anything but a HOLD reason' do
    expect([described_class.stop(:threads_overflow).exit_code, described_class.hold(:no_checks)])
      .to eq([2, { reason: 'no_checks', message: 'No check has run on the head.' }])
    expect(SkillSupport::Outcome.ask([described_class.ask(:fork_pull_request, accept_with: %w[--accept-fork x])])
                                .exit_code).to eq(3)
    expect { described_class.hold(:threads_overflow) }.to raise_error(ArgumentError)
  end
end

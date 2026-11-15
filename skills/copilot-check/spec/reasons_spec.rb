# frozen_string_literal: true

require_relative '../lib/copilot_check/reasons'

RSpec.describe CopilotCheck::Reasons do
  it "is each script's whole enum of stops and asks, apart from the reasons promote-check's verdict holds for" do
    expect(described_class::SETUP)
      .to eq(%i[not_a_pull_request_number pull_request_not_open fork_pull_request scripts_unreviewed
                copilot_id_changed])
    expect(described_class::THREADS).to eq(%i[copilot_id_changed copilot_unrecognised threads_overflow])
    expect(described_class::REREVIEW).to eq(%i[copilot_id_changed copilot_timeout])
    expect(described_class::PROMOTE_CHECK)
      .to eq(%i[copilot_id_changed copilot_unrecognised threads_overflow head_changed head_unreadable
                ready_state_unexpected])
    expect(described_class::HOLD & described_class::ALL).to be_empty
  end

  it 'gives every reason, and only those, a constant message' do
    expect(described_class::MESSAGES.keys).to match_array(described_class::ALL + described_class::HOLD)
    expect(described_class::MESSAGES.values).to all(be_frozen.and(be_a(String)))
  end

  it "tells the lead to undo the ready on any of verify's stops" do
    %i[head_changed head_unreadable ready_state_unexpected].each do |reason|
      expect(described_class::MESSAGES[reason]).to include('Run gh pr ready --undo'), reason.to_s
    end
  end

  it "says on a timeout that nothing else may notice a missed review, not that Copilot's can't be a required one" do
    expect(described_class::MESSAGES[:copilot_timeout])
      .to include('Copilot occasionally does not review, and nothing else may notice: say so plainly in the report.')
    expect(described_class::MESSAGES[:copilot_timeout]).not_to include('required approval')
  end

  it "says in the fork's ask that a yes means Phase 4 runs the fork's specs and linter as the owner" do
    expect(described_class::MESSAGES[:fork_pull_request])
      .to include("a yes means Phase 4 runs the fork's specs and linter as the owner")
  end

  it "asks about the scripts under the reason the shared examination gives, naming this skill's directory" do
    expect(described_class::SCRIPTS_UNREVIEWED).to eq(SkillSupport::ScriptsCheckout::REASON)
    expect(described_class::MESSAGES[:scripts_unreviewed]).to include('skills/copilot-check or skills/_support')
  end

  it 'builds stops and asks the contract accepts, and refuses to hold for anything but a HOLD reason' do
    expect([described_class.stop(:threads_overflow).exit_code, described_class.hold(:no_checks)])
      .to eq([2, { reason: 'no_checks', message: 'No check has run on the head.' }])
    expect(SkillSupport::Outcome.ask([described_class.ask(:fork_pull_request, accept_with: %w[--accept-fork x])])
                                .exit_code).to eq(3)
    expect { described_class.hold(:threads_overflow) }.to raise_error(ArgumentError)
  end
end

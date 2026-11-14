# frozen_string_literal: true

require_relative '../lib/do/reasons'

RSpec.describe Do::Reasons do
  it 'is the whole enum of stops and asks, none of them both' do
    expect(described_class::ALL).to eq(%i[not_an_issue gate_advisory no_origin comments_truncated
                                          untrusted_author_criteria gate_record_missing])
    expect(described_class::STOPS & described_class::ASKS).to be_empty
  end

  it 'gives every reason a constant message, and not_an_issue one for each thing a reference can turn out to be' do
    expect(described_class::MESSAGES.keys + [described_class::NOT_AN_ISSUE])
      .to match_array(described_class::ALL)
    expect(described_class::NOT_AN_ISSUE_MESSAGES.keys)
      .to eq(%i[not_a_reference pull_request missing_issue missing_repository moved])
    expect(described_class::MESSAGES.values + described_class::NOT_AN_ISSUE_MESSAGES.values).to all(be_frozen)
  end

  it 'builds outcomes the contract accepts' do
    expect([described_class.not_an_issue(:moved).to_h['reason'],
            described_class.stop(:gate_advisory, read: []).exit_code,
            SkillSupport::Outcome.ask([described_class.ask(:no_origin)]).reasons])
      .to eq(['not_an_issue', 2, ['no_origin']])
  end
end

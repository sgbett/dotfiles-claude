# frozen_string_literal: true

require_relative '../lib/do/reasons'

RSpec.describe Do::Reasons do
  it "is each script's whole enum of stops and asks, none of them both" do
    expect(described_class::PREFLIGHT)
      .to eq(%i[not_an_issue host_not_logged_in gate_advisory remote_missing host_mismatch remote_unresolvable
                push_remote_not_this_repository fork_not_writable pr_target_not_this_repository
                branch_is_base_or_default base_missing checked_out_pr remote_tips_differ untrusted_pull_request
                no_origin comments_truncated untrusted_author_criteria gate_record_missing local_branch_unpushed
                scripts_unreviewed])
    expect(described_class::RECORD)
      .to eq(%i[not_an_issue host_not_logged_in no_ledger box_missing body_changed untrusted_issue_author
                not_a_sub_issue untrusted_sub_issue no_such_finding gate_advisory gate_answered gate_line_missing
                ambiguous_checkbox no_origin gate_unanswered scripts_unreviewed])
    expect([described_class::PREFLIGHT_STOPS & described_class::PREFLIGHT_ASKS,
            described_class::RECORD_STOPS & described_class::RECORD_ASKS]).to eq([[], []])
    expect(described_class::ALL).to match_array(described_class::PREFLIGHT | described_class::RECORD)
  end

  it 'lists why record closes holds an issue open apart from any stop or ask' do
    expect(described_class::HELD)
      .to eq(%i[unverified_boxes unverified_items open_elsewhere untrusted_elsewhere not_in_ledger])
    expect(described_class::HELD & described_class::ALL).to be_empty
  end

  it "tells the user, for every stop on the remotes, to run /do from a checkout of the issue's repository or a fork" do
    %i[remote_missing host_mismatch remote_unresolvable push_remote_not_this_repository fork_not_writable
       pr_target_not_this_repository].each do |reason|
      expect(described_class::MESSAGES.fetch(reason))
        .to end_with("Run /do owner/repo#N from a checkout of the issue's repository or of a fork of it."), reason.to_s
    end
  end

  it 'gives every reason a constant message, and not_an_issue one for each thing a reference can turn out to be' do
    expect(described_class::MESSAGES.keys + [described_class::NOT_AN_ISSUE])
      .to match_array(described_class::ALL)
    expect(described_class::NOT_AN_ISSUE_MESSAGES.keys)
      .to eq(%i[not_a_reference pull_request missing_issue missing_repository moved])
    expect(described_class::MESSAGES.values + described_class::NOT_AN_ISSUE_MESSAGES.values).to all(be_frozen)
  end

  it 'stops only record calls that act on boxes on ambiguous_checkbox, telling the user, never to run it again' do
    message = described_class::MESSAGES[:ambiguous_checkbox]

    expect([described_class::PREFLIGHT.include?(:ambiguous_checkbox), described_class::RECORD_STOPS])
      .to match([false, include(:ambiguous_checkbox)])
    expect(message).to end_with('Tell the user, who can fix those lines and run /do again.')
    expect(message).not_to include('same call again')
  end

  it 'has the user run /do owner/repo#N when a bare number has no origin, as a run never changes its issue' do
    expect(described_class::MESSAGES[:no_origin]).to include('tell the user to run /do owner/repo#N')
  end

  it 'builds outcomes the contract accepts' do
    expect([described_class.not_an_issue(:moved).to_h['reason'],
            described_class.stop(:gate_advisory, read: []).exit_code,
            SkillSupport::Outcome.ask([described_class.ask(:no_origin)]).reasons])
      .to eq(['not_an_issue', 2, ['no_origin']])
  end
end

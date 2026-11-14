# frozen_string_literal: true

require_relative 'support/gate_calls'

# `promote-check verify`: after the lead marks the pull request ready, its
# head must still be the commit `check` judged, and it must be open, out of
# draft and without auto-merge; anything else stops, so the lead undoes the
# ready.
RSpec.describe CopilotCheck::ReadyVerification do
  include CopilotCheck::Testing::GateCalls

  let(:head) { CopilotCheck::Testing::GateCalls::HEAD }
  let(:other) { CopilotCheck::Testing::GateCalls::OTHER_COMMIT }

  def verify(expected_head = head)
    run_promote_check(['verify', '--pr', '18', '--head', expected_head])
  end

  def ready(**fields)
    pull_request_response('isDraft' => false, **fields)
  end

  it 'goes on when the head is still the one checked, and the pull request open and ready without auto-merge' do
    expect_gate(through: :pull_request, pull_request: { response: ready })

    expect(verify).to eq([0, { 'status' => 'proceed',
                               'pull_request' => { 'number' => 18, 'head' => head, 'state' => 'OPEN',
                                                   'is_draft' => false, 'auto_merge' => false } }])
  end

  it 'stops, giving the new head, when it has changed' do
    expect_gate(through: :pull_request, pull_request: { response: ready })

    exit_code, output = verify(other)

    expect([exit_code, output['reason'], output['pull_request'].values_at('number', 'head')])
      .to eq([2, 'head_changed', [18, head]])
    expect(output['message']).to include('Run gh pr ready --undo')
  end

  it 'stops, from the same read, when the pull request is still a draft, not open, or has auto-merge on' do
    cases = { { 'isDraft' => true } => ['OPEN', true, false], { 'state' => 'MERGED' } => ['MERGED', false, false],
              { 'state' => 'CLOSED' } => ['CLOSED', false, false],
              { 'autoMergeRequest' => { 'enabledAt' => '2026-11-14T20:00:00Z' } } => ['OPEN', false, true] }

    cases.each do |fields, shown|
      expect_gate(through: :pull_request, pull_request: { response: ready(**fields) })

      exit_code, output = verify

      expect([exit_code, output['reason'], output['pull_request'].values_at('state', 'is_draft', 'auto_merge')])
        .to eq([2, 'ready_state_unexpected', shown]), fields.inspect
      expect(output['message']).to include('Run gh pr ready --undo')
    end
  end

  it "stops when the head can't be read: the repository, the query or its answer" do
    expect_repository_step(stdout: '', exit_status: 1, stderr: "failed to run git: fatal: not a git repository\n")
    expect_gate(through: :pull_request, pull_request: { stdout: '{"errors":[{"message":"Bad credentials"}]}',
                                                        exit_status: 1 })
    expect_gate(through: :pull_request, pull_request: { response: pull_request_response('headRefOid' => 'x') })

    outputs = Array.new(3) { verify }

    expect(outputs.map { |exit_code, output| [exit_code, output['reason']] }).to all(eq([2, 'head_unreadable']))
    expect(outputs.map { |_exit_code, output| output['session_only']['error'] })
      .to match([include('not a git repository'), include('Bad credentials'), 'invalid commit_sha'])
  end
end

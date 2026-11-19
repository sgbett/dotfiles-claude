# frozen_string_literal: true

require_relative 'support/script_calls'

RSpec.describe CopilotCheck::ReviewRequest do
  include CopilotCheck::Testing::ScriptCalls

  let(:pull_request_id) { CopilotCheck::Testing::ScriptCalls::PULL_REQUEST_ID }

  # Runs `rereview request` on #18, the mutation answered with +response+
  # unless it is nil, as on a dry run.
  def request(response, *flags, **result)
    expect_repo_view
    expect_pull_request_id
    expect_copilot_review_request(response, **result) if response
    outcome = CopilotCheck::Rereview.call(['request', '--pr', '18', *flags], runner: fake_runner)
    [outcome.exit_code, JSON.parse(outcome.to_json)]
  end

  it "requests Copilot's review of the pull request, naming nothing else" do
    expect(request(copilot_review_answer(true)))
      .to eq([0, { 'status' => 'proceed', 'pull_request' => { 'number' => 18 }, 'review_request' => 'requested',
                   'dry_run' => false }])
    expect(JSON.parse(copilot_review_request)['variables']).to eq('pullRequestId' => pull_request_id)
  end

  it 'reads a request already pending, as a ruleset makes on a push, as a review underway, noting it for the session' do
    exit_code, output = request(copilot_review_answer(false, 'REQUEST_CONFLICT', pull_request: nil))

    expect([exit_code, output['review_request']]).to eq([0, 'underway'])
    expect(output['session_only']).to eq('failure_reason' => 'REQUEST_CONFLICT')
  end

  it 'stops on every other failure reason GitHub documents, naming it' do
    described_class::REFUSALS.each do |reason|
      exit_code, output = request(copilot_review_answer(false, reason))

      expect([exit_code, output['reason'], output['pull_request']])
        .to eq([2, 'copilot_request_refused', { 'number' => 18 }]), reason
      expect(output['message']).to include("failureReason #{reason},"), reason
    end
  end

  it "knows every failure reason GitHub's schema gives, and sends and selects only fields it has" do
    schema = JSON.parse(fixture('graphql/copilot-code-review-schema.json'))['data']
    names = ->(type, list) { schema.dig(type, list).map { |entry| entry['name'] } }
    answer = copilot_review_answer(false, 'REQUEST_CONFLICT')

    expect(names.call('failureReasons', 'enumValues'))
      .to match_array(described_class::REFUSALS + [described_class::REQUEST_CONFLICT])
    expect(names.call('input', 'inputFields')).to include(*JSON.parse(copilot_review_request)['variables'].keys)
    expect(names.call('payload', 'fields')).to include(*answer.dig('data', 'requestCopilotCodeReview').keys)
  end

  it "fails as a tool on a failure it can't explain, or a success that gives a reason" do
    [copilot_review_answer(false), copilot_review_answer(false, 'SOMETHING_NEW'),
     copilot_review_answer(nil, 'NO_QUOTA_REMAINING')].each do |answer|
      expect { request(answer) }.to raise_error(SkillSupport::UnexpectedResponse, /requestCopilotCodeReview/)
    end
    expect { request(copilot_review_answer(true, 'REQUEST_CONFLICT')) }
      .to raise_error(SkillSupport::UnexpectedResponse, /succeeded, yet gave a failureReason/)
  end

  it 'fails as a tool on an answer that names another pull request, or none on a success' do
    [copilot_review_answer(true, pull_request: 'PR_other'), copilot_review_answer(true, pull_request: nil),
     copilot_review_answer(false, 'REQUEST_CONFLICT', pull_request: 'PR_other'),
     { 'data' => { 'requestCopilotCodeReview' => nil } }].each do |answer|
      expect { request(answer) }.to raise_error(SkillSupport::UnexpectedResponse, /requestCopilotCodeReview/)
    end
  end

  it 'fails as a tool on any GraphQL error' do
    expect { request(graphql_errors('Could not resolve to a node with the global id of PR_x'), exit_status: 1) }
      .to raise_error(SkillSupport::GraphqlError, /Could not resolve/)
  end

  it 'requests nothing on a dry run' do
    expect(request(nil, '--dry-run').last.values_at('review_request', 'dry_run')).to eq(['skipped', true])
  end
end

RSpec.describe 'skills/copilot-check/bin/rereview request' do
  include CopilotCheck::Testing::ScriptCalls

  # Runs bin/rereview request on #18 through the gh shim, the mutation
  # answered with +answer+.
  def run_request(answer)
    shim = install_gh_shim([repo_view_entry, recorded_graphql_entry('pull-request-id-18'),
                            graphql_entry(copilot_review_request, stdout: JSON.generate(answer))])
    exit_code, output, stderr = run_script('rereview', 'request', '--pr', '18')
    [exit_code, output, stderr, shim.unmatched_calls]
  end

  it 'finds the pull request as recorded, then requests the review, through gh alone' do
    exit_code, output, stderr, unmatched = run_request(copilot_review_answer(true))

    expect([exit_code, stderr, unmatched, output['review_request']]).to eq([0, '', [], 'requested'])
  end

  it 'stops on a refusal under a reason of its own enum' do
    exit_code, output, stderr, unmatched = run_request(copilot_review_answer(false, 'NO_QUOTA_REMAINING'))

    expect([exit_code, stderr, unmatched, output['reason']]).to eq([2, '', [], 'copilot_request_refused'])
  end
end

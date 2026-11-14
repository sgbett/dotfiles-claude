# frozen_string_literal: true

require_relative 'support/script_calls'

RSpec.describe CopilotCheck::ReviewRequest do
  include CopilotCheck::Testing::ScriptCalls

  let(:pull_request_id) { CopilotCheck::Testing::ScriptCalls::PULL_REQUEST_ID }
  let(:requested) { { 'data' => { 'requestReviews' => { 'pullRequest' => { 'id' => pull_request_id } } } } }

  # Runs `rereview request` on #18, the mutation answered with +response+
  # unless it is nil, as on a dry run.
  def request(response, *flags, **result)
    expect_repo_view
    expect_pull_request_id
    expect_request_reviews(response, **result) if response
    outcome = CopilotCheck::Rereview.call(['request', '--pr', '18', *flags], runner: fake_runner)
    [outcome.exit_code, JSON.parse(outcome.to_json)]
  end

  it "requests Copilot's review by its bot id, keeping the reviewers already requested" do
    expect(request(requested)).to eq([0, { 'status' => 'proceed', 'pull_request' => { 'number' => 18 },
                                           'review_request' => 'requested', 'dry_run' => false }])
    expect(described_class::MUTATION).to include('union: true')
    expect(JSON.parse(request_reviews_request)['variables'])
      .to eq('pullRequestId' => pull_request_id, 'botIds' => ['BOT_kgDOCnlnWA'])
  end

  it 'reads an error saying a review is already running as one underway, keeping its words for the session' do
    exit_code, output = request(graphql_errors('Copilot is already reviewing this pull request'), exit_status: 1)

    expect([exit_code, output['review_request']]).to eq([0, 'underway'])
    expect(output['session_only']['error']).to include('already reviewing')
  end

  it 'fails as a tool on any other error, and on an answer that names another pull request' do
    expect { request(graphql_errors('Could not resolve to a node with the global id of BOT_x'), exit_status: 1) }
      .to raise_error(SkillSupport::GraphqlError, /Could not resolve/)
    expect { request({ 'data' => { 'requestReviews' => { 'pullRequest' => { 'id' => 'PR_other' } } } }) }
      .to raise_error(SkillSupport::UnexpectedResponse, /didn't answer with the pull request/)
  end

  it 'requests nothing on a dry run' do
    expect(request(nil, '--dry-run').last.values_at('review_request', 'dry_run')).to eq(['skipped', true])
  end
end

RSpec.describe 'skills/copilot-check/bin/rereview request' do
  include CopilotCheck::Testing::ScriptCalls

  it 'finds the pull request as recorded, then requests the review, through gh alone' do
    answer = { 'data' => { 'requestReviews' => { 'pullRequest' => {
      'id' => CopilotCheck::Testing::ScriptCalls::PULL_REQUEST_ID
    } } } }
    shim = install_gh_shim([repo_view_entry, recorded_graphql_entry('pull-request-id-18'),
                            graphql_entry(request_reviews_request, stdout: JSON.generate(answer))])

    exit_code, output, stderr = run_script('rereview', 'request', '--pr', '18')

    expect([exit_code, stderr, shim.unmatched_calls, output['review_request']]).to eq([0, '', [], 'requested'])
  end
end

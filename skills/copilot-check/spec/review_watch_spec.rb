# frozen_string_literal: true

require_relative 'support/script_calls'

RSpec.describe CopilotCheck::ReviewWatch do
  include CopilotCheck::Testing::ScriptCalls

  let(:mark) { CopilotCheck::Testing::ScriptCalls::REVIEWED_AT }
  let(:newer) { '2026-11-13T09:15:02Z' }
  # A clock that moves only when the watcher sleeps, so no example waits.
  let(:now) { [0] }
  let(:sleeps) { [] }
  let(:timing) do
    described_class::Timing.new(timeout: 100, interval: 40, clock: -> { now.first },
                                sleeper: lambda { |seconds|
                                  sleeps << seconds
                                  now[0] += seconds
                                })
  end

  def expect_failed_poll
    expect_latest_review('', exit_status: 1, stderr: "gh: Bad Gateway (HTTP 502)\n")
  end

  # Runs the watcher on #18 from +since+, each poll answered in turn by
  # +polls+: a latest review query answer, or :fails for a poll gh fails.
  def watch(*polls, since: mark)
    expect_repo_view
    polls.each { |poll| poll == :fails ? expect_failed_poll : expect_latest_review(poll) }
    options = CopilotCheck::RereviewArguments.parse(['watch', '--pr', '18', '--since', since])
    outcome = described_class.new(options, runner: fake_runner, timing: timing).call
    [outcome.exit_code, JSON.parse(outcome.to_json)]
  end

  it 'proceeds with the new review once one newer than the mark comes, polling at the interval' do
    exit_code, output = watch(fixture('graphql/latest-review-18.json'), latest_review_response(newer))

    expect([exit_code, output]).to eq([0, { 'status' => 'proceed', 'pull_request' => { 'number' => 18 },
                                            'submitted_at' => newer }])
    expect(sleeps).to eq([40])
  end

  it 'takes any review as new after the epoch, waiting while there is none' do
    exit_code, output = watch(latest_review_response(nil), latest_review_response('2026-07-04T15:07:49Z'),
                              since: '1970-01-01T00:00:00Z')

    expect([exit_code, output['submitted_at']]).to eq([0, '2026-07-04T15:07:49Z'])
  end

  it "stops at once when Copilot's latest review carries another id" do
    exit_code, output = watch(latest_review_response(newer, author: 'BOT_kgDOOtherId'))

    expect([exit_code, output.values_at('status', 'reason')]).to eq([2, %w[stop copilot_id_changed]])
    expect(sleeps).to eq([])
  end

  it 'stops once the deadline passes with no newer review, counting the polls that failed' do
    recorded = fixture('graphql/latest-review-18.json')
    exit_code, output = watch(recorded, :fails, recorded)

    expect([exit_code, output.values_at('status', 'reason', 'failed_polls')])
      .to eq([2, ['stop', 'copilot_timeout', 1]])
    expect(output['session_only']['error']).to include('Bad Gateway')
    expect([sleeps, now.first]).to eq([[40, 40, 40], 120])
  end

  it 'retries a failed poll and never reads it as a review, even when gh printed one' do
    failed = latest_review_response(newer).merge(graphql_errors('Something went wrong'))
    expect_repo_view
    expect_latest_review(failed, exit_status: 1)
    expect_latest_review(latest_review_response(newer))
    options = CopilotCheck::RereviewArguments.parse(['watch', '--pr', '18', '--since', mark])

    outcome = described_class.new(options, runner: fake_runner, timing: timing).call

    expect([outcome.exit_code, sleeps]).to eq([0, [40]])
  end

  it 'waits 15 minutes, polling every 40 seconds, unless told otherwise' do
    expect(described_class::TIMING.to_h.values_at(:timeout, :interval)).to eq([900, 40])
  end
end

RSpec.describe 'skills/copilot-check/bin/rereview watch' do
  include CopilotCheck::Testing::ScriptCalls

  def install(latest)
    install_gh_shim([repo_view_entry, graphql_entry(recorded_request('latest-review-18'), stdout: latest)])
  end

  it "proceeds at once with #18's recorded review, newer than the mark it is given" do
    shim = install(fixture('graphql/latest-review-18.json'))

    exit_code, output, stderr = run_script('rereview', 'watch', '--pr', '18', '--since', '2026-11-12T20:00:00Z')

    expect([exit_code, stderr, shim.unmatched_calls]).to eq([0, '', []])
    expect(output['submitted_at']).to eq(CopilotCheck::Testing::ScriptCalls::REVIEWED_AT)
  end

  it 'stops with exit 2 when the latest review carries another id' do
    install(JSON.generate(latest_review_response('2026-11-13T09:15:02Z', author: 'BOT_kgDOOtherId')))

    exit_code, output, = run_script('rereview', 'watch', '--pr', '18', '--since', '2026-11-12T20:00:00Z')

    expect([exit_code, output['reason']]).to eq([2, 'copilot_id_changed'])
  end
end

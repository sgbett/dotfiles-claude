# frozen_string_literal: true

require_relative 'support/script_calls'

RSpec.describe CopilotCheck::ThreadResolution do
  include CopilotCheck::Testing::ScriptCalls

  # Two of #3's unresolved threads, which the cases below answer.
  let(:first) { 'PRRT_kwDOQzoXSs6OWG23' }
  let(:second) { 'PRRT_kwDOQzoXSs6OWG29' }

  # #3 as recorded, with our reply now the last comment on +answered+.
  def answered(*answered, name: 'threads-3')
    threads_response(name).tap do |response|
      threads_pull_request(response)['reviewThreads']['nodes'].each do |thread|
        thread['last']['nodes'] = [{ 'viewerDidAuthor' => true }] if answered.include?(thread['id'])
      end
    end
  end

  # Runs `threads resolve` on the fetch +response+, after which the block
  # expects the calls the case makes.
  def resolve(response, *flags, number: 3)
    expect_repo_view
    expect_threads(response, number: number)
    yield if block_given?
    outcome = CopilotCheck::ThreadsCommand.call(['resolve', '--pr', number.to_s, *flags], runner: fake_runner)
    [outcome.exit_code, JSON.parse(outcome.to_json)]
  end

  it 'resolves each unresolved Copilot thread last answered by us, after reading it again' do
    exit_code, output = resolve(answered(first, second)) do
      [first, second].each do |id|
        expect_thread_reread(id, thread_reread_response(id))
        expect_resolve(id)
      end
    end

    expect([exit_code, output]).to eq([0, { 'status' => 'proceed', 'pull_request' => { 'number' => 3 },
                                            'resolved' => [first, second], 'changed' => [], 'dry_run' => false }])
  end

  it 'leaves a thread that someone answered or resolved since the fetch, or that is gone, for the next round' do
    gone = 'PRRT_kwDOQzoXSs6OWG3A'
    output = resolve(answered(first, second, gone)) do
      expect_thread_reread(first, thread_reread_response(first, ours: false))
      expect_thread_reread(second, thread_reread_response(second, resolved: true))
      expect_thread_reread(gone, { 'data' => { 'node' => nil } })
    end.last

    expect(output.values_at('resolved', 'changed')).to eq([[], [first, second, gone]])
  end

  it "leaves #14's thread, which GitHub, as recorded, says someone has resolved since" do
    response = answered(name: 'threads-14').tap do |changed|
      threads_pull_request(changed)['reviewThreads']['nodes'].first['isResolved'] = false
    end

    output = resolve(response, number: 14) do
      fake_runner.expect_call(CopilotCheck::Testing::GateCalls::GRAPHQL,
                              stdin: recorded_request('review-thread-14'),
                              stdout: fixture('graphql/review-thread-14.json'))
    end.last

    expect(output.values_at('resolved', 'changed')).to eq([[], ['PRRT_kwDOQzoXSs6wwd00']])
  end

  it 'never resolves a thread still to do, one Copilot did not start, or one already resolved' do
    response = answered(first).tap do |changed|
      threads = threads_pull_request(changed)['reviewThreads']['nodes']
      threads.find { |thread| thread['id'] == first }['first']['nodes'].first['author'] =
        { '__typename' => 'User', 'login' => 'example' }
    end

    expect(resolve(response).last.values_at('resolved', 'changed')).to eq([[], []])
  end

  it 'resolves nothing on a dry run, giving the threads it would resolve' do
    expect(resolve(answered(first), '--dry-run').last.values_at('resolved', 'changed', 'dry_run'))
      .to eq([[first], [], true])
  end

  it "fails as a tool when the mutation's answer doesn't show the thread resolved" do
    expect do
      resolve(answered(first)) do
        expect_thread_reread(first, thread_reread_response(first))
        expect_resolve(first, resolved: false)
      end
    end.to raise_error(SkillSupport::UnexpectedResponse, /read back as resolved/)
  end

  it 'stops where the thread fetch does, resolving nothing' do
    response = answered(first).tap do |changed|
      threads_pull_request(changed)['comments']['pageInfo']['hasPreviousPage'] = true
    end

    expect(resolve(response).last.values_at('status', 'reason')).to eq(%w[stop threads_overflow])
  end
end

RSpec.describe 'skills/copilot-check/bin/threads resolve' do
  include CopilotCheck::Testing::ScriptCalls

  it 'reads the thread again, then resolves it, through gh alone' do
    id = 'PRRT_kwDOQzoXSs6OWG23'
    threads = threads_response('threads-3')
    threads_pull_request(threads)['reviewThreads']['nodes'].find { |thread| thread['id'] == id }['last']['nodes'] =
      [{ 'viewerDidAuthor' => true }]
    shim = install_gh_shim(
      [repo_view_entry, graphql_entry(recorded_request('threads-3'), stdout: JSON.generate(threads)),
       graphql_entry(graphql_request(CopilotCheck::ThreadResolution::THREAD, 'id' => id),
                     stdout: JSON.generate(thread_reread_response(id))),
       graphql_entry(graphql_request(CopilotCheck::ThreadResolution::RESOLVE, 'id' => id),
                     stdout: JSON.generate(resolve_response(id)))]
    )

    exit_code, output, stderr = run_script('threads', 'resolve', '--pr', '3')

    expect([exit_code, stderr, shim.unmatched_calls, output['resolved']]).to eq([0, '', [], [id]])
    expect(shim.calls.length).to eq(4)
  end
end

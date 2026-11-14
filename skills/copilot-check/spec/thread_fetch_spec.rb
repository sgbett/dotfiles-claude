# frozen_string_literal: true

require_relative 'support/script_calls'

RSpec.describe CopilotCheck::ThreadFetch do
  include CopilotCheck::Testing::ScriptCalls

  let(:bodies) { sandbox.path('round-1') }
  # #3's five threads still to do, by their first comment's id, as recorded.
  let(:todo_comments) { [3_523_393_698, 3_523_393_706, 3_523_393_712, 3_523_393_716, 3_523_393_720] }
  let(:todo_reviews) { [4_629_353_421, 4_629_383_851, 4_629_808_973] }

  def fetch(response = threads_response('threads-3'), number: 3)
    expect_repo_view
    expect_threads(response, number: number)
    outcome = CopilotCheck::ThreadsCommand.call(['fetch', '--pr', number.to_s, '--bodies-dir', bodies],
                                                runner: fake_runner)
    [outcome.exit_code, JSON.parse(outcome.to_json)]
  end

  def recorded_threads
    threads_pull_request(threads_response('threads-3'))['reviewThreads']['nodes']
  end

  it "gives #3's threads and reviews still to do, as recorded, by their ids and locations" do
    exit_code, output = fetch

    expect([exit_code, output['status'], output['pull_request']]).to eq([0, 'proceed', { 'number' => 3 }])
    expect(output['todo_threads'].map { |thread| thread['comment_id'] }).to eq(todo_comments)
    expect(output['todo_threads'].first)
      .to eq('thread_id' => 'PRRT_kwDOQzoXSs6OWG23', 'comment_id' => 3_523_393_698, 'outdated' => false, 'line' => 109,
             'original_line' => 109, 'original_commit' => 'c53d8440d9c3179cf9a5406eb286f9c2550a09d2',
             'body_file' => 'thread-3523393698.md', 'github_text' => { 'path' => 'skills/copilot-check/SKILL.md' })
    expect(output['todo_reviews'])
      .to eq(todo_reviews.map { |id| { 'review_id' => id, 'body_file' => "review-#{id}.md" } })
  end

  it 'writes each body, Copilot\'s text, to its file and never to stdout' do
    _exit_code, output = fetch
    bodies_by_comment = recorded_threads.to_h do |thread|
      thread['first']['nodes'].first.values_at('databaseId', 'body')
    end

    output['todo_threads'].each do |thread|
      body = bodies_by_comment.fetch(thread['comment_id'])
      expect(File.read(File.join(bodies, thread['body_file']))).to eq(body)
      expect(output.to_json).not_to include(body[0, 40])
    end
    expect(Dir.children(bodies).length).to eq(todo_comments.length + todo_reviews.length)
    expect(File.stat(bodies).mode & 0o777).to eq(0o700)
  end

  it "gives an outdated thread's location as its original line in its original commit" do
    response = threads_response('threads-3')
    first = threads_pull_request(response)['reviewThreads']['nodes'].first
    first['isResolved'] = false
    first['last']['nodes'] = [{ 'viewerDidAuthor' => false }]

    thread = fetch(response).last['todo_threads'].first

    expect(thread.values_at('outdated', 'line', 'original_line', 'original_commit'))
      .to eq([true, nil, 4, 'c8e07c074ff42da979bccbbef2d6e61465ad1e31'])
  end

  it 'gives nothing to do once every thread is answered and every review marked, as on #14 recorded' do
    response = threads_response('threads-14')
    answer = { 'viewerDidAuthor' => true, 'body' => '<!-- copilot-check:answered 5670324332 -->' }
    threads_pull_request(response)['comments']['nodes'] << answer

    exit_code, output = fetch(response, number: 14)

    expect([exit_code, output['todo_threads'], output['todo_reviews']]).to eq([0, [], []])
  end

  describe 'where Phase 2a stops' do
    def stop(response)
      exit_code, output = fetch(response)
      [exit_code, output['status'], output['reason']]
    end

    it 'stops on a list past its page, a Copilot id change, and Copilot threads it no longer recognises' do
      overflow = threads_response('threads-3').tap do |response|
        threads_pull_request(response)['reviewThreads']['pageInfo']['hasNextPage'] = true
      end
      id_changed = threads_response('threads-3').tap do |response|
        threads_pull_request(response)['reviews']['nodes'].last['author'] = { 'id' => 'BOT_kgDOOtherId' }
      end
      unrecognised = threads_response('threads-3').tap do |response|
        threads_pull_request(response)['reviewThreads']['nodes'].each do |thread|
          thread['first']['nodes'].first['author'] = { '__typename' => 'User', 'login' => 'example' }
        end
      end

      expect([overflow, id_changed, unrecognised].map { |response| stop(response) })
        .to eq([[2, 'stop', 'threads_overflow'], [2, 'stop', 'copilot_id_changed'],
                [2, 'stop', 'copilot_unrecognised']])
      expect(File.exist?(bodies)).to be(false)
    end

    it 'fails as a tool on GraphQL errors, even beside data' do
      expect_repo_view
      expect_threads(threads_response('threads-3').merge(graphql_errors('Something went wrong')), number: 3,
                                                                                                  exit_status: 1)

      expect { CopilotCheck::ThreadsCommand.call(['fetch', '--pr', '3', '--bodies-dir', bodies], runner: fake_runner) }
        .to raise_error(SkillSupport::GraphqlError, /Something went wrong/)
    end
  end
end

RSpec.describe 'skills/copilot-check/bin/threads fetch' do
  include CopilotCheck::Testing::ScriptCalls

  it "gives #3's threads and reviews still to do as recorded, whatever RUBYOPT says" do
    shim = install_gh_shim([repo_view_entry, recorded_graphql_entry('threads-3')])

    exit_code, output, stderr = run_script('threads', 'fetch', '--pr', '3', '--bodies-dir', sandbox.path('round-1'),
                                           environment: hostile_environment)

    expect([exit_code, stderr, shim.unmatched_calls]).to eq([0, '', []])
    expect([output['todo_threads'].length, output['todo_reviews'].length]).to eq([5, 3])
    expect(Dir.children(sandbox.path('round-1')).length).to eq(8)
  end
end

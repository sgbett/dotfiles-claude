# frozen_string_literal: true

require_relative 'support/gate_calls'

RSpec.describe CopilotCheck::Threads do
  include CopilotCheck::Testing::GateCalls

  subject(:threads) { described_class.new(SkillSupport::Gh.new(host: 'github.com', runner: fake_runner)) }

  let(:here) { CopilotCheck::Testing::GateCalls::HERE }

  def expect_fetch(response, number: 14, **result)
    fake_runner.expect_call(CopilotCheck::Testing::GateCalls::GRAPHQL,
                            stdin: graphql_request(described_class::QUERY, described_class.variables(here, number)),
                            stdout: as_json(response), **result)
  end

  def fetch(response, number: 14)
    expect_fetch(response, number: number)
    threads.fetch(here, number)
  end

  # #14 as recorded, with its one thread, which we answered and someone
  # resolved, changed by the block.
  def changed_threads
    response = threads_response('threads-14')
    yield threads_pull_request(response)
    response
  end

  def thread_of(pull_request)
    pull_request['reviewThreads']['nodes'].first
  end

  def stop_reason
    yield
  rescue CopilotCheck::Stop => e
    e.reason
  end

  it 'sends the query and variables the fixtures were recorded with' do
    { 'threads-3' => 3, 'threads-14' => 14, 'threads-18' => 18 }.each do |name, number|
      expect(JSON.parse(fixture("graphql/#{name}.request.json")))
        .to eq('query' => described_class::QUERY, 'variables' => described_class.variables(here, number)), name
    end
  end

  it "reads #14 as recorded: Copilot's latest review, no thread to do, and the one review no comment marks" do
    result = fetch(threads_response('threads-14'))

    expect(result.latest_review.to_h).to eq(submitted_at: '2026-10-27T16:03:42Z', comments: 0,
                                            commit: '56b92d3c76c8d5f09feb05ca05af160e8838d8cf')
    expect([result.todo_threads, result.todo_reviews.map(&:review_id)]).to eq([[], [5_670_324_332]])
  end

  it "reads #18 as recorded: both of Copilot's reviews still to do, as no comment answers them" do
    result = fetch(threads_response('threads-18'), number: 18)

    expect(result.todo_reviews.map(&:review_id)).to eq(CopilotCheck::Testing::GateCalls::REVIEWS)
    expect(result.latest_review.commit).to eq(CopilotCheck::Testing::GateCalls::HEAD)
  end

  it "gives no latest review when Copilot hasn't reviewed the pull request" do
    response = changed_threads do |pull_request|
      pull_request['latest']['nodes'] = []
      pull_request['reviews']['nodes'] = []
      pull_request['reviewThreads']['nodes'] = []
    end

    expect(fetch(response).to_h.values_at(:latest_review, :todo_reviews)).to eq([nil, []])
  end

  describe 'a thread to do' do
    it "is unresolved, started by Copilot and last answered by someone else, with 2a's fields" do
      response = changed_threads do |pull_request|
        thread_of(pull_request)['isResolved'] = false
        thread_of(pull_request)['last']['nodes'] = [{ 'viewerDidAuthor' => false }]
      end

      expect(fetch(response).todo_threads.map(&:to_h))
        .to eq([{ thread_id: 'PRRT_kwDOQzoXSs6wwd00', outdated: true, comment_id: 4_390_690_635,
                  path: 'skills/copilot-check/SKILL.md', line: nil, original_line: 128,
                  original_commit: '739168d6b150410baaee818cc3badc0eddd5cb0e',
                  body: thread_of(threads_pull_request(response))['first']['nodes'].first['body'] }])
    end

    it 'is not one we answered last, one resolved, or one Copilot did not start' do
      ours = changed_threads { |pull_request| thread_of(pull_request)['isResolved'] = false }
      resolved = changed_threads do |pull_request|
        thread_of(pull_request)['last']['nodes'] = [{ 'viewerDidAuthor' => false }]
      end
      strangers = changed_threads do |pull_request|
        thread_of(pull_request)['isResolved'] = false
        thread_of(pull_request)['first']['nodes'].first['author'] = { '__typename' => 'User', 'login' => 'example' }
      end

      expect([ours, resolved, strangers].map { |response| fetch(response).todo_threads }).to eq([[], [], []])
    end

    it "counts one whose last comment GitHub doesn't give as still to do" do
      response = changed_threads do |pull_request|
        thread_of(pull_request)['isResolved'] = false
        thread_of(pull_request)['last']['nodes'] = []
      end

      expect(fetch(response).todo_threads.length).to eq(1)
    end
  end

  describe 'a thread to resolve' do
    it 'is unresolved, started by Copilot and last answered by us, as #14 was before it was resolved' do
      ours = changed_threads { |pull_request| thread_of(pull_request)['isResolved'] = false }

      expect(fetch(ours).resolvable_threads).to eq(['PRRT_kwDOQzoXSs6wwd00'])
    end

    it "is not one resolved, one a stranger answered last, one Copilot didn't start, or one GitHub says little of" do
      resolved = threads_response('threads-14')
      strangers = changed_threads do |pull_request|
        thread_of(pull_request)['isResolved'] = false
        thread_of(pull_request)['last']['nodes'] = [{ 'viewerDidAuthor' => false }]
      end
      not_copilots = changed_threads do |pull_request|
        thread_of(pull_request)['isResolved'] = false
        thread_of(pull_request)['first']['nodes'].first['author'] = { '__typename' => 'User', 'login' => 'example' }
      end
      unsaid = changed_threads do |pull_request|
        thread_of(pull_request).delete('isResolved')
        thread_of(pull_request)['last']['nodes'] = []
      end

      expect([resolved, strangers, not_copilots, unsaid].map { |response| fetch(response).resolvable_threads })
        .to eq([[], [], [], []])
    end
  end

  describe 'a review to do' do
    it "drops out only once a comment of ours carries its answered marker, never a stranger's" do
      response = changed_threads do |pull_request|
        pull_request['comments']['nodes'] << { 'viewerDidAuthor' => false,
                                               'body' => '<!-- copilot-check:answered 5670324332 -->' }
      end
      answered = changed_threads do |pull_request|
        pull_request['comments']['nodes'] << { 'viewerDidAuthor' => true,
                                               'body' => "Done.\n<!-- copilot-check:answered 5670324332 -->\n" }
      end

      expect(fetch(response).todo_reviews.map(&:review_id)).to eq([5_670_324_332])
      expect(fetch(answered).todo_reviews).to eq([])
    end
  end

  describe 'where Phase 2a stops' do
    it 'stops when a review under Copilot\'s login, its latest one or a thread it started carries another id' do
      other_id = { 'id' => 'BOT_kgDOOtherId' }
      cases = [
        changed_threads { |pull_request| pull_request['reviews']['nodes'].first['author'] = other_id },
        changed_threads { |pull_request| pull_request['latest']['nodes'].first['author'] = other_id },
        changed_threads { |pull_request| thread_of(pull_request)['first']['nodes'].first['author']['id'] = 'BOT_other' }
      ]

      expect(cases.map { |response| stop_reason { fetch(response) } }).to all(eq(:copilot_id_changed))
    end

    it "stops when Copilot's latest review made inline comments but no thread is recognised as Copilot's" do
      none = changed_threads do |pull_request|
        pull_request['latest']['nodes'].first['comments']['totalCount'] = 2
        pull_request['reviewThreads']['nodes'] = []
      end
      a_strangers = changed_threads do |pull_request|
        pull_request['latest']['nodes'].first['comments']['totalCount'] = 1
        thread_of(pull_request)['first']['nodes'].first['author'] = { '__typename' => 'User', 'login' => 'example' }
      end

      expect([none, a_strangers].map { |response| stop_reason { fetch(response) } })
        .to eq(%i[copilot_unrecognised copilot_unrecognised])
    end

    it 'stops when the threads, the reviews or the comments run past their one page' do
      flags = { 'reviewThreads' => 'hasNextPage', 'reviews' => 'hasPreviousPage', 'comments' => 'hasPreviousPage' }
      cases = flags.map do |list, flag|
        changed_threads { |pull_request| pull_request[list]['pageInfo'][flag] = true }
      end

      expect(cases.map { |response| stop_reason { fetch(response) } }).to all(eq(:threads_overflow))
    end

    it 'fails on GraphQL errors, even beside data' do
      response = threads_response('threads-14').merge('errors' => [{ 'message' => 'Something went wrong' }])
      expect_fetch(response, exit_status: 1)

      expect { threads.fetch(here, 14) }.to raise_error(SkillSupport::GraphqlError, /Something went wrong/)
    end
  end
end

# frozen_string_literal: true

require_relative 'support/gate_calls'

RSpec.describe CopilotCheck::PullRequestQuery do
  include CopilotCheck::Testing::GateCalls

  subject(:query) { described_class.new(SkillSupport::Gh.new(host: 'github.com', runner: fake_runner)) }

  let(:here) { CopilotCheck::Testing::GateCalls::HERE }

  it 'sends the query and variables the fixture was recorded with' do
    expect(JSON.parse(fixture('graphql/pull-request-18.request.json')))
      .to eq('query' => described_class::QUERY, 'variables' => described_class.variables(here, 18))
  end

  it 'reads #18 as recorded: merged, not a draft, its mergeability unknown, and the viewer its author' do
    expect_pull_request_step(response: fixture('graphql/pull-request-18.json'))

    expect(query.fetch(here, 18).to_h)
      .to eq(state: 'MERGED', draft: false, cross_repository: false, head: CopilotCheck::Testing::GateCalls::HEAD,
             mergeable: 'UNKNOWN', changed_files: 2, author: 'sgbett', auto_merge: false, viewer: 'sgbett')
  end

  it 'tells auto-merge on, and gives no author for a deleted account' do
    expect_pull_request_step(response: pull_request_response('autoMergeRequest' => { 'enabledAt' => '2026-11-14' },
                                                             'author' => nil))

    expect(query.fetch(here, 18).to_h.values_at(:auto_merge, :author)).to eq([true, nil])
  end

  it 'fails rather than guess when a flag, the count or the head is missing' do
    [{ 'isDraft' => nil }, { 'isCrossRepository' => 'false' }, { 'changedFiles' => nil }].each do |fields|
      expect_pull_request_step(response: pull_request_response(**fields))
      expect { query.fetch(here, 18) }.to raise_error(SkillSupport::UnexpectedResponse), fields.inspect
    end
    expect_pull_request_step(response: pull_request_response('headRefOid' => nil))
    expect { query.fetch(here, 18) }.to raise_error(SkillSupport::InvalidIdentifier, 'invalid commit_sha')
  end
end

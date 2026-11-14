# frozen_string_literal: true

require_relative 'support/script_calls'

RSpec.describe CopilotCheck::LatestReview do
  include CopilotCheck::Testing::ScriptCalls

  subject(:latest) { described_class.new(SkillSupport::Gh.new(host: 'github.com', runner: fake_runner)) }

  let(:here) { CopilotCheck::Testing::GateCalls::HERE }

  it 'sends the query and variables the fixtures were recorded with' do
    [18, 20].each do |number|
      expect(JSON.parse(fixture("graphql/latest-review-#{number}.request.json")))
        .to eq('query' => described_class::QUERY, 'variables' => described_class.variables(here, number)), number.to_s
    end
  end

  it "gives when Copilot's latest review of #18 came, as recorded" do
    expect_latest_review

    expect(latest.submitted_at(here, 18)).to eq(CopilotCheck::Testing::ScriptCalls::REVIEWED_AT)
  end

  it 'gives nothing for #20, which Copilot never reviewed, as recorded' do
    expect_latest_review(fixture('graphql/latest-review-20.json'), number: 20)

    expect(latest.submitted_at(here, 20)).to be_nil
  end

  it "stops when the latest review under Copilot's login carries another id, or none" do
    [latest_review_response('2026-11-13T09:00:00Z', author: 'BOT_kgDOOtherId'),
     latest_review_response('2026-11-13T09:00:00Z', author: nil)].each do |response|
      expect_latest_review(response)
      expect { latest.submitted_at(here, 18) }
        .to raise_error(an_instance_of(CopilotCheck::Stop).and(having_attributes(reason: :copilot_id_changed)))
    end
  end

  it 'fails on a review without a timestamp, an answer without reviews, and GraphQL errors beside data' do
    expect_latest_review(latest_review_response(nil).tap do |response|
      response['data']['repository']['pullRequest']['reviews']['nodes'] = [{ 'author' => { 'id' => 'BOT_kgDOCnlnWA' } }]
    end)
    expect { latest.submitted_at(here, 18) }.to raise_error(SkillSupport::InvalidIdentifier, 'invalid submitted_at')

    expect_latest_review({ 'data' => { 'repository' => nil } })
    expect { latest.submitted_at(here, 18) }.to raise_error(SkillSupport::UnexpectedResponse)

    expect_latest_review(latest_review_response(nil).merge(graphql_errors('Something went wrong')), exit_status: 1)
    expect { latest.submitted_at(here, 18) }.to raise_error(SkillSupport::GraphqlError, /Something went wrong/)
  end
end

RSpec.describe CopilotCheck::Timestamp do
  it 'takes a UTC ISO 8601 timestamp, with or without fractions of a second, and nothing else' do
    expect(%w[2026-11-12T20:23:51Z 2026-11-12T20:23:51.250Z].map { |value| described_class.check!(value) })
      .to eq(%w[2026-11-12T20:23:51Z 2026-11-12T20:23:51.250Z])
    ['2026-11-12', '2026-11-12T20:23:51+00:00', '2026-11-12T25:23:51Z', ' 2026-11-12T20:23:51Z', nil].each do |value|
      expect { described_class.check!(value) }.to raise_error(SkillSupport::InvalidIdentifier), value.inspect
    end
  end

  it 'compares as times, and the epoch comes before any review' do
    expect(described_class.after?('2026-11-12T20:23:51.5Z', '2026-11-12T20:23:51Z')).to be(true)
    expect(described_class.after?('2026-11-12T20:23:51Z', '2026-11-12T20:23:51Z')).to be(false)
    expect(described_class.after?('2026-07-04T15:07:49Z', described_class::EPOCH)).to be(true)
  end
end

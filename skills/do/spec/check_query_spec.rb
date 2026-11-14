# frozen_string_literal: true

require_relative 'support/check_calls'

RSpec.describe Do::CheckQuery do
  include Do::Testing::CheckCalls

  subject(:query) { described_class.new(SkillSupport::Gh.new(host: 'github.com', runner: fake_runner)) }

  let(:here) { Do::Testing::CheckCalls::HERE }
  let(:branch) { Do::Testing::CheckCalls::BRANCH }

  def issue_response(type: 'Issue', home: here, issue_home: here)
    node = { '__typename' => type }
    node['repository'] = { 'nameWithOwner' => issue_home } if type == 'Issue'
    { 'data' => { 'viewer' => { 'login' => 'sgbett' },
                  'repository' => { 'nameWithOwner' => home, 'issueOrPullRequest' => node } } }
  end

  it 'sends the queries and variables the fixtures were recorded with' do
    { 'check-issue-24' => [described_class::ISSUE_QUERY, described_class.issue_variables(here, 24)],
      'base-master' => [described_class::BASE_QUERY, described_class.base_variables(here, 'master')],
      'base-missing' => [described_class::BASE_QUERY, described_class.base_variables(here, 'feat/#24+no-such-branch')],
      'pull-requests-24' => [described_class::PULL_REQUESTS_QUERY,
                             described_class.pull_request_variables(here, branch)] }
      .each do |name, (query_text, variables)|
        expect(JSON.parse(fixture("graphql/#{name}.request.json")))
          .to eq('query' => query_text, 'variables' => variables), name
      end
  end

  describe '#issue' do
    it 'reads the recorded issue, with the viewer, the repository as GitHub names it and its default branch' do
      expect_issue_step

      expect(query.issue(here, 24).to_h).to eq(kind: :issue, viewer: 'sgbett', repository: here,
                                               default_branch: 'master')
    end

    it 'gives no default branch for a repository with no commits, which has none' do
      response = issue_response
      response['data']['repository']['defaultBranchRef'] = nil
      expect_issue_step(response: response)

      expect(query.issue(here, 24).default_branch).to be_nil
    end

    it "gives the repository's current name for an old one, as GitHub resolves a rename" do
      expect_issue_step(repository: 'example-old-owner/old-name')

      expect(query.issue('example-old-owner/old-name', 24).repository).to eq(here)
    end

    it 'tells a pull request, and an issue that now lives in another repository' do
      expect_issue_step(response: issue_response(type: 'PullRequest'))
      expect_issue_step(response: issue_response(issue_home: 'example-owner/new-home'))

      expect([query.issue(here, 24).kind, query.issue(here, 24).kind]).to eq(%i[pull_request moved])
    end

    it 'tells a number that names nothing, as recorded, and a repository that is not there' do
      expect_issue_step(response: fixture('graphql/missing-issue.json'), number: 99_999, exit_status: 1)
      expect_issue_step(response: { 'data' => { 'viewer' => { 'login' => 'sgbett' }, 'repository' => nil },
                                    'errors' => [{ 'type' => 'NOT_FOUND', 'path' => ['repository'],
                                                   'message' => 'x' }] },
                        repository: 'example-owner/nothing', exit_status: 1)

      expect([query.issue(here, 99_999).kind, query.issue('example-owner/nothing', 24).kind])
        .to eq(%i[missing_issue missing_repository])
    end

    it 'fails as a tool on any other error, or an answer it cannot read' do
      expect_issue_step(response: issue_response.merge('errors' => [{ 'type' => 'FORBIDDEN', 'message' => 'No' }]),
                        exit_status: 1)
      expect_issue_step(response: { 'data' => { 'viewer' => nil, 'repository' => { 'nameWithOwner' => here } } })
      expect_issue_step(response: { 'data' => { 'viewer' => nil, 'repository' => {} } })
      expect_issue_step(response: { 'data' => { 'viewer' => nil, 'repository' => nil } })

      expect { query.issue(here, 24) }.to raise_error(SkillSupport::GraphqlError)
      expect { query.issue(here, 24) }.to raise_error(SkillSupport::UnexpectedResponse, /neither an issue/)
      2.times { expect { query.issue(here, 24) }.to raise_error(SkillSupport::UnexpectedResponse, /nameless/) }
    end
  end

  describe '#base_commit' do
    it "gives the commit the base branch points to, as recorded, or nil when it doesn't exist" do
      expect_base_step
      expect_base_step(base: 'feat/#24+no-such-branch', response: fixture('graphql/base-missing.json'))

      expect([query.base_commit(here, 'master'), query.base_commit(here, 'feat/#24+no-such-branch')])
        .to eq([Do::Testing::CheckCalls::BASE_SHA, nil])
    end

    it 'fails as a tool when no repository comes back' do
      expect_base_step(response: { 'data' => { 'repository' => nil } })

      expect { query.base_commit(here, 'master') }.to raise_error(SkillSupport::UnexpectedResponse)
    end
  end

  describe '#pull_requests' do
    it 'reads the recorded answer for a branch with none open' do
      expect_pull_requests_step

      expect(query.pull_requests(here, branch)).to eq([])
    end

    it 'reads each one with its author and head repository, nil when GitHub names none' do
      expect_pull_requests_step(nodes: [pull_request_node(30, 'sgbett', viewer: true),
                                        pull_request_node(31, nil, association: 'NONE', head: nil)])

      expect(query.pull_requests(here, branch).map(&:to_h))
        .to eq([{ number: 30, author: Do::Author.new(login: 'sgbett', association: 'OWNER', viewer_did_author: true),
                  head_repository: here },
                { number: 31, author: Do::Author.new(login: nil, association: 'NONE', viewer_did_author: false),
                  head_repository: nil }])
    end

    it 'fails as a tool when they overflow a page' do
      response = pull_requests_response([])
      response['data']['repository']['pullRequests']['pageInfo']['hasNextPage'] = true
      expect_pull_requests_step(response: response)

      expect { query.pull_requests(here, branch) }.to raise_error(SkillSupport::IncompleteResults)
    end
  end
end

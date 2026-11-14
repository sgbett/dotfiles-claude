# frozen_string_literal: true

require_relative '../lib/do/issue_query'
require_relative 'support/issue_responses'

RSpec.describe Do::IssueQuery do
  include Do::Testing::IssueResponses

  subject(:query) { described_class.new(SkillSupport::Gh.new(host: 'github.com', runner: fake_runner)) }

  def fetch(repository = recorded_repository, number = 24)
    query.fetch(repository, number)
  end

  it 'sends the query and variables the fixtures were recorded with' do
    { 'issue-24' => 24, 'pull-request-25' => 25, 'missing-issue' => 99_999 }.each do |name, number|
      expect(JSON.parse(fixture("graphql/#{name}.request.json")))
        .to eq(JSON.parse(issue_request(recorded_repository, number))), name
    end
  end

  it 'reads the recorded issue, its ledger comment and its repository' do
    expect_issue_query(fixture('graphql/issue-24.json'))
    result = fetch

    expect([result.kind, result.viewer, result.repository_id, result.default_branch_ref])
      .to eq([:issue, 'sgbett', 'R_kgDOQzoXSg', 'master'])
    expect(result.repository.to_h).to eq(name_with_owner: recorded_repository, owner: 'sgbett', visibility: 'PUBLIC')
    expect(result.issue.author.to_h).to eq(login: 'sgbett', association: 'OWNER', viewer_did_author: true)
    expect(result.issue.edits.to_h).to eq(logins: ['sgbett'] * 5, complete: true)
    expect([result.comments.map(&:database_id), result.comments_complete]).to eq([[6_867_069_660], true])
    expect(result.labels.map(&:name)).to include('project:hlr')
    expect([result.parent, result.sub_issues, result.branches, result.project_items]).to eq([nil, [], [], 0])
  end

  it 'tells a pull request number, as recorded' do
    expect_issue_query(fixture('graphql/pull-request-25.json'), number: 25)

    expect(fetch(recorded_repository, 25).kind).to eq(:pull_request)
  end

  it 'tells a number that names nothing, as recorded, from a repository that is not there' do
    expect_issue_query(fixture('graphql/missing-issue.json'), number: 99_999, exit_status: 1,
                                                              stderr: fixture('graphql/missing-issue.stderr'))
    missing_repository = { 'data' => { 'viewer' => { 'login' => 'sgbett' }, 'repository' => nil },
                           'errors' => [{ 'type' => 'NOT_FOUND', 'path' => ['repository'], 'message' => 'Not here' }] }
    expect_issue_query(missing_repository, repository: 'example-owner/nothing', number: 1, exit_status: 1)

    expect([fetch(recorded_repository, 99_999).kind, fetch('example-owner/nothing', 1).kind])
      .to eq(%i[missing_issue missing_repository])
  end

  it 'raises any other GraphQL error, a NOT_FOUND elsewhere included' do
    [[{ 'type' => 'FORBIDDEN', 'path' => ['repository'], 'message' => 'Forbidden' }],
     [{ 'type' => 'NOT_FOUND', 'path' => %w[repository issueOrPullRequest parent], 'message' => 'Gone' }],
     [{ 'type' => 'NOT_FOUND', 'path' => ['repository'], 'message' => 'Gone' },
      { 'type' => 'RATE_LIMITED', 'message' => 'Slow down' }]].each do |errors|
      expect_issue_query(issue_response.merge('errors' => errors), exit_status: 1)

      expect { fetch }.to raise_error(SkillSupport::GraphqlError), errors.inspect
    end
  end

  it 'tells an issue that now lives in another repository' do
    expect_issue_query(issue_response { |issue| issue['repository']['nameWithOwner'] = 'example-owner/new-home' })

    expect(fetch.kind).to eq(:moved)
  end

  it 'raises IncompleteResults when the sub-issues, branches or their pull requests overflow a page' do
    branch = { 'name' => 'feat/24-x', 'associatedPullRequests' => connection([], more: true) }
    [->(issue, _data) { issue['subIssues']['pageInfo']['hasNextPage'] = true },
     ->(_issue, data) { data['repository']['refs'] = connection([], more: true) },
     ->(_issue, data) { data['repository']['refs'] = connection([branch]) }].each do |change|
      expect_issue_query(issue_response(&change))

      expect { fetch }.to raise_error(SkillSupport::IncompleteResults)
    end
  end

  it 'records labels cut off at a page, keeping the page, as labels decide nothing' do
    expect_issue_query(fixture('graphql/issue-24.json'))
    expect_issue_query(issue_response { |_issue, data| data['repository']['labels']['pageInfo']['hasNextPage'] = true })

    expect([fetch, fetch].map { |result| [result.labels.length, result.labels_complete] })
      .to eq([[10, true], [10, false]])
  end

  it 'records cut-off comments, editors and renamers for its caller to fail closed on' do
    expect_issue_query(issue_response do |issue|
      issue['comments']['pageInfo']['hasNextPage'] = true
      issue['parent'] = issue_node(3, 'example-owner/upstream', by: authored_by('example-author'))
                        .merge('userContentEdits' => editors(['example-author', nil]),
                               'timelineItems' => connection([], more: true))
    end)
    result = fetch

    expect(result.comments_complete).to be(false)
    expect(result.parent.edits.to_h).to eq(logins: ['example-author', nil], complete: false)
  end

  it 'collects whoever renamed an issue beside whoever edited its body' do
    expect_issue_query(issue_response do |issue|
      issue['parent'] = issue_node(3, 'example-owner/upstream', by: authored_by('example-author'))
                        .merge('timelineItems' => connection([{ 'actor' => { 'login' => 'example-stranger' } }]))
    end)

    expect(fetch.parent.edits.to_h).to eq(logins: %w[example-author example-stranger], complete: true)
  end

  it 'reads a deleted author as a nil login' do
    expect_issue_query(issue_response { |issue| issue['author'] = nil })

    expect(fetch.issue.author.login).to be_nil
  end

  it 'keeps only feat/<N>-* branches, whose pull requests go into this repository' do
    pull_requests = [{ 'number' => 30, 'author' => { 'login' => 'sgbett' }, 'authorAssociation' => 'OWNER',
                       'viewerDidAuthor' => true, 'baseRepository' => { 'nameWithOwner' => 'SGBETT/dotfiles-claude' } },
                     { 'number' => 4, 'author' => { 'login' => 'sgbett' }, 'authorAssociation' => 'NONE',
                       'viewerDidAuthor' => true, 'baseRepository' => { 'nameWithOwner' => 'example-owner/upstream' } }]
    refs = [{ 'name' => 'feat/24-work', 'associatedPullRequests' => connection(pull_requests) },
            { 'name' => 'old/feat/24-work', 'associatedPullRequests' => connection([]) }]
    expect_issue_query(issue_response { |_issue, data| data['repository']['refs'] = connection(refs) })

    expect(fetch.branches.map { |branch| [branch.name, branch.pull_requests.map(&:number)] })
      .to eq([['feat/24-work', [30]]])
  end

  describe '#branch_names' do
    it "lists the issue's feat/<N>-* branches, though GitHub matches the name anywhere" do
      expect_branches_query(20, %w[feat/20-parent-work feat/200-other old/feat/20-parent-work])

      expect(query.branch_names(recorded_repository, 20)).to eq(['feat/20-parent-work'])
    end

    it 'raises IncompleteResults when they overflow a page' do
      expect_branches_query(20, ['feat/20-a'], more: true)

      expect { query.branch_names(recorded_repository, 20) }.to raise_error(SkillSupport::IncompleteResults)
    end
  end
end

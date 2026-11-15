# frozen_string_literal: true

require_relative 'support/script_calls'

RSpec.describe CopilotCheck::PullRequestView do
  include CopilotCheck::Testing::ScriptCalls

  subject(:view) { described_class.new(fake_runner, repository) }

  let(:repository) do
    CopilotCheck::CheckoutRepository::Repository.new(host: 'github.com', name_with_owner: 'sgbett/dotfiles-claude')
  end

  it 'reads #18 by number in the checkout repository, as recorded, and what the start file records of it' do
    expect_pr_view(response: pr_view_response)

    pull_request = view.fetch(18)

    expect([pull_request.to_h, pull_request.open?])
      .to eq([{ number: 18, base: 'master', draft: false, cross_repository: false,
                head: CopilotCheck::Testing::GateCalls::HEAD, state: 'MERGED' }, false])
    expect(pull_request.start_state(repository, chained: true))
      .to eq('number' => 18, 'repository' => 'github.com/sgbett/dotfiles-claude', 'baseRefName' => 'master',
             'isCrossRepository' => false, 'isDraft' => false, 'chained' => true)
  end

  it 'tells an open pull request from a closed or merged one' do
    { 'OPEN' => true, 'CLOSED' => false, 'MERGED' => false }.each do |state, open|
      expect_pr_view(response: pr_view_response(state: state))
      expect(view.fetch(18).open?).to be(open), state
    end
  end

  it "reads the current branch's pull request when given no number, as gh can't with -R" do
    branch = open_pr_view_response(number: 26, url: 'https://github.com/sgbett/dotfiles-claude/pull/26')
    expect_pr_view(nil, response: branch)

    expect(view.fetch(nil).number).to eq(26)
  end

  it 'fails when gh finds none, as on a branch with no pull request or a detached HEAD' do
    expect_pr_view(nil, exit_status: 1, stdout: '', stderr: "could not determine current branch: not on any branch\n")

    expect { view.fetch(nil) }.to raise_error(SkillSupport::GhError, /could not determine current branch/)
  end

  it "fails on another pull request, or one in another repository than the checkout's" do
    [pr_view_response(number: 19),
     pr_view_response(url: 'https://github.com/example-owner/dotfiles-claude/pull/18'),
     pr_view_response(url: 'https://ghe.example.com/sgbett/dotfiles-claude/pull/18'),
     pr_view_response(url: 'https://github.com/sgbett/dotfiles-claude/pull/19')].each do |response|
      expect_pr_view(response: response)
      expect { view.fetch(18) }.to raise_error(SkillSupport::UnexpectedResponse), response.inspect
    end
  end

  it 'fails rather than guess when a flag, the base, the state or the head is missing, or gh prints no JSON' do
    unusable = [pr_view_response(isDraft: nil), pr_view_response(isCrossRepository: 'false'),
                pr_view_response(baseRefName: ''), pr_view_response(state: nil), pr_view_response(state: 'open')]
    unusable.each do |response|
      expect_pr_view(response: response)
      expect { view.fetch(18) }.to raise_error(SkillSupport::UnexpectedResponse), response.inspect
    end
    expect_pr_view(response: pr_view_response(headRefOid: nil))
    expect { view.fetch(18) }.to raise_error(SkillSupport::InvalidIdentifier, 'invalid commit_sha')
    expect_pr_view(response: 'not json')
    expect { view.fetch(18) }.to raise_error(SkillSupport::UnexpectedResponse, /other than JSON/)
  end
end

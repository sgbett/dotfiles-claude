# frozen_string_literal: true

require_relative '../lib/do/issue_locator'

RSpec.describe Do::IssueLocator do
  subject(:locator) { described_class.new(fake_runner) }

  let(:origin) { 'https://github.com/sgbett/dotfiles-claude.git' }

  def locate(argument)
    locator.locate(argument, &:to_h)
  end

  def expect_origin(url = origin)
    fake_runner.expect_call(%w[git remote get-url origin], stdout: "#{url}\n")
  end

  def expect_origin_view(stdout, url: origin)
    fake_runner.expect_call(['gh', 'repo', 'view', url, '--json', 'nameWithOwner,url'], stdout: stdout)
  end

  it 'yields a reference given in full once gh is logged in to its host, calling nothing else' do
    expect_gh_login

    expect(locate('sgbett/dotfiles-claude#24')).to eq(host: 'github.com', repository: 'sgbett/dotfiles-claude',
                                                      number: 24)
  end

  it "yields a bare number in the repository origin resolves to, on the host gh's answer names, checking it once" do
    expect_origin
    expect_gh_login
    expect_origin_view(fixture('repo-view/origin.json'))

    expect(locate('#24')).to eq(host: 'github.com', repository: 'sgbett/dotfiles-claude', number: 24)
  end

  it "checks the host gh's answer names as well, when it isn't the one origin's URL gives" do
    url = 'https://ghe-alias.example.com/example-owner/example-repo.git'
    expect_origin(url)
    expect_gh_login('ghe-alias.example.com')
    expect_origin_view('{"nameWithOwner":"example-owner/example-repo",' \
                       '"url":"https://ghe.example.com/example-owner/example-repo"}', url: url)
    expect_gh_login('ghe.example.com', logged_in: false)

    expect(locate('24').to_h).to include('status' => 'stop', 'reason' => 'host_not_logged_in',
                                         'host' => 'ghe.example.com')
  end

  it 'stops on a host gh has no account logged in to, before any request to it' do
    expect_gh_login('ghe.example.com', logged_in: false)
    expect_origin('https://ghe.example.com/example-owner/example-repo.git')
    expect_gh_login('ghe.example.com', logged_in: false)

    %w[https://ghe.example.com/example-owner/example-repo/issues/7 7].each do |argument|
      outcome = described_class.new(fake_runner).locate(argument) { raise 'yielded' }

      expect(outcome.to_h).to eq('status' => 'stop', 'reason' => 'host_not_logged_in',
                                 'message' => Do::Reasons::MESSAGES[:host_not_logged_in], 'host' => 'ghe.example.com')
    end
  end

  it 'returns the stop or ask that comes first, yielding nothing' do
    fake_runner.expect_call(%w[git remote get-url origin], exit_status: 2)

    expect([locate('not-an-issue').reasons, locate('24').reasons]).to eq([['not_an_issue'], ['no_origin']])
  end

  it 'takes an origin at a local path, or at a host alias that is no host name, for none, asking gh nothing' do
    ['/srv/git/example-repo.git', 'git@github-work:sgbett/dotfiles-claude.git'].each do |url|
      expect_origin(url)

      expect(locate('24').reasons).to eq(['no_origin']), url
    end
  end

  it "fails as a tool when gh's answer for origin names no repository URL" do
    expect_origin
    expect_gh_login
    expect_origin_view('{"nameWithOwner":"sgbett/dotfiles-claude"}')

    expect { locate('24') }.to raise_error(SkillSupport::UnexpectedResponse, /no repository URL/)
  end
end

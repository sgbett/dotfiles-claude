# frozen_string_literal: true

require_relative '../lib/do/issue_locator'

RSpec.describe Do::IssueLocator do
  subject(:locator) { described_class.new(fake_runner) }

  let(:origin) { 'https://github.com/sgbett/dotfiles-claude.git' }

  def locate(argument)
    locator.locate(argument, &:to_h)
  end

  def expect_origin_view(stdout)
    fake_runner.expect_call(%w[git remote get-url origin], stdout: "#{origin}\n")
    fake_runner.expect_call(['gh', 'repo', 'view', origin, '--json', 'nameWithOwner,url'], stdout: stdout)
  end

  it 'yields a reference given in full without calling anything' do
    expect(locate('sgbett/dotfiles-claude#24')).to eq(host: 'github.com', repository: 'sgbett/dotfiles-claude',
                                                      number: 24)
  end

  it "yields a bare number in the repository origin resolves to, on the host gh's answer names" do
    expect_origin_view(fixture('repo-view/origin.json'))

    expect(locate('#24')).to eq(host: 'github.com', repository: 'sgbett/dotfiles-claude', number: 24)
  end

  it 'returns the stop or ask that comes first, yielding nothing' do
    fake_runner.expect_call(%w[git remote get-url origin], exit_status: 2)

    expect([locate('not-an-issue').reasons, locate('24').reasons]).to eq([['not_an_issue'], ['no_origin']])
  end

  it "fails as a tool when gh's answer for origin names no repository URL" do
    expect_origin_view('{"nameWithOwner":"sgbett/dotfiles-claude"}')

    expect { locate('24') }.to raise_error(SkillSupport::UnexpectedResponse, /no repository URL/)
  end
end

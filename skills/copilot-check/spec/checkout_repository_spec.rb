# frozen_string_literal: true

require_relative 'support/gate_calls'

RSpec.describe CopilotCheck::CheckoutRepository do
  let(:repo_view) { CopilotCheck::Testing::GateCalls::REPO_VIEW }

  def resolve(stdout, **result)
    fake_runner.expect_call(repo_view, stdout: stdout, **result)
    described_class.resolve(fake_runner)
  end

  it 'takes the repository gh resolves from the checkout, as recorded, with its host' do
    repository = resolve(fixture('repo-view/checkout.json'))

    expect([repository.host, repository.name_with_owner, repository.argument])
      .to eq(['github.com', 'sgbett/dotfiles-claude', 'github.com/sgbett/dotfiles-claude'])
  end

  it "takes another host from the repository's URL" do
    repository = resolve('{"nameWithOwner":"example-owner/repo","url":"https://GHE.example.com/example-owner/repo"}')

    expect(repository.argument).to eq('ghe.example.com/example-owner/repo')
  end

  it "fails when gh can't resolve one, as outside a checkout" do
    expect { resolve('', exit_status: 1, stderr: "failed to run git: fatal: not a git repository\n") }
      .to raise_error(SkillSupport::GhError, /not a git repository/)
  end

  it "fails on a URL that isn't the https URL of the repository it names, and on output that isn't JSON" do
    ['{"nameWithOwner":"example-owner/repo","url":"https://github.com/example-owner/other"}',
     '{"nameWithOwner":"example-owner/repo","url":"http://github.com/example-owner/repo"}',
     '{"nameWithOwner":"example-owner/repo"}', 'not json', '[]'].each do |stdout|
      expect { resolve(stdout) }.to raise_error(SkillSupport::UnexpectedResponse), stdout
    end
  end

  it 'fails on a name that is not a repository' do
    expect { resolve('{"nameWithOwner":"-x/repo","url":"https://github.com/-x/repo"}') }
      .to raise_error(SkillSupport::InvalidIdentifier, 'invalid repository')
  end
end

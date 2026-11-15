# frozen_string_literal: true

require_relative '../lib/copilot_check/push_remote'

# Against remotes of the sandbox's repository, as git gives their push
# URLs, with gh's answers on the fake runner.
RSpec.describe CopilotCheck::PushRemote do
  subject(:push_remote) do
    described_class.new(SkillSupport::CommandRunner.new, SkillSupport::Gh.new(host: 'github.com', runner: fake_runner))
  end

  let(:here) { 'sgbett/dotfiles-claude' }
  let(:url) { 'https://github.com/sgbett/dotfiles-claude.git' }
  let(:ssh_url) { 'git@github.com:sgbett/dotfiles-claude.git' }
  let(:fork_url) { 'https://github.com/example-owner/dotfiles-claude.git' }

  def git(*arguments)
    system('git', *arguments, exception: true)
  end

  # Gives origin +urls+ as its pushurls, in place of any it had.
  def push_to(*urls)
    system('git', 'config', '--unset-all', 'remote.origin.pushurl')
    urls.each { |push_url| git('config', '--add', 'remote.origin.pushurl', push_url) }
  end

  # gh resolving +push_url+ to +repository+.
  def expect_view(push_url, repository = here)
    fake_runner.expect_call(['gh', 'repo', 'view', push_url, '--json', 'nameWithOwner'],
                            stdout: JSON.generate('nameWithOwner' => repository))
  end

  def pushes_only_to?(remote = 'origin')
    push_remote.pushes_only_to?(sandbox.work_directory, remote, here)
  end

  before { git('remote', 'add', 'origin', url) }

  it 'passes a remote whose url GitHub resolves to the repository, ignoring case as GitHub does' do
    expect_view(url, 'SGBett/Dotfiles-Claude')

    expect(pushes_only_to?).to be(true)
  end

  it 'passes a remote whose every pushurl is the repository, asking nothing of its url, which no push uses' do
    git('remote', 'set-url', 'origin', fork_url)
    push_to(url, ssh_url)
    expect_view(url)
    expect_view(ssh_url)

    expect(pushes_only_to?).to be(true)
  end

  it 'fails a remote with a pushurl GitHub resolves to another repository, asking about no URL after it' do
    push_to(fork_url, url)
    expect_view(fork_url, 'example-owner/dotfiles-claude')

    expect(pushes_only_to?).to be(false)
  end

  it 'asks about each URL as git rewrites it for a push' do
    git('config', 'url.ssh://git@github.com/.pushInsteadOf', 'https://github.com/')
    expect_view('ssh://git@github.com/sgbett/dotfiles-claude.git')

    expect(pushes_only_to?).to be(true)
  end

  it "fails a URL off the repository's host, a local path or an SSH host alias, before asking gh about any" do
    ['https://gitlab.example.com/sgbett/dotfiles-claude.git', '/srv/git/dotfiles-claude.git',
     'git@github-work:sgbett/dotfiles-claude.git'].each do |other|
      push_to(url, other)

      expect(pushes_only_to?).to be(false), other
    end
  end

  it 'fails a remote with no url, which git gives its own name, a local path' do
    git('config', 'remote.mirror.fetch', '+refs/heads/*:refs/remotes/mirror/*')

    expect(pushes_only_to?('mirror')).to be(false)
  end

  it 'fails a URL on the host that gh would read as a local path, asking gh nothing' do
    push_to('deploy@github.com:sgbett/dotfiles-claude.git')

    expect(pushes_only_to?).to be(false)
  end

  it "fails as a tool when gh can't resolve a URL, or names no repository for it" do
    fake_runner.expect_call(['gh', 'repo', 'view', url, '--json', 'nameWithOwner'],
                            exit_status: 1, stderr: "GraphQL: Could not resolve to a Repository\n")
    expect { pushes_only_to? }.to raise_error(SkillSupport::GhError, /Could not resolve/)

    fake_runner.expect_call(['gh', 'repo', 'view', url, '--json', 'nameWithOwner'], stdout: '{}')
    expect { pushes_only_to? }.to raise_error(SkillSupport::InvalidIdentifier, 'invalid repository')
  end
end

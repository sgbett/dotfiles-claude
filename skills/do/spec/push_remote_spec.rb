# frozen_string_literal: true

require_relative '../lib/do/checkout'
require_relative '../lib/do/push_remote'

RSpec.describe Do::PushRemote do
  subject(:push_remote) do
    described_class.new(checkout: Do::Checkout.new(fake_runner), github: github, host: 'github.com', repository: here)
  end

  let(:github) { SkillSupport::Gh.new(host: 'github.com', runner: fake_runner) }

  let(:here) { 'sgbett/dotfiles-claude' }
  let(:origin_url) { 'https://github.com/sgbett/dotfiles-claude.git' }
  let(:fork_url) { 'https://github.com/bettison-org/ai-software-architect.git' }

  def view(name, parent = nil, permission: 'WRITE')
    { 'nameWithOwner' => name, 'parent' => parent && { 'name' => parent.split('/').last,
                                                       'owner' => { 'login' => parent.split('/').first } },
      'viewerPermission' => permission }
  end

  def expect_remote(urls, remotes: ['origin'])
    fake_runner.expect_call(%w[git remote], stdout: remotes.map { |remote| "#{remote}\n" }.join)
    fake_runner.expect_call(%w[git remote get-url --push --all origin], stdout: urls.map { |url| "#{url}\n" }.join)
  end

  def expect_view(url, stdout: nil, **result)
    fake_runner.expect_call(['gh', 'repo', 'view', url, '--json', 'nameWithOwner,parent,viewerPermission'],
                            stdout: stdout, **result)
  end

  describe '.classify' do
    it 'tells this repository, ignoring case as GitHub does' do
      expect(described_class.classify(view('SGBETT/Dotfiles-Claude'), here)).to eq(:this_repository)
    end

    it 'tells a fork whose parent is this repository, ignoring case' do
      expect(described_class.classify(view('example-fork-owner/dotfiles-claude', 'Sgbett/DOTFILES-claude'), here))
        .to eq(:fork)
    end

    it 'calls anything else other: an unrelated repository, or a fork of one' do
      [view('example-owner/unrelated'), view('example-owner/dotfiles-claude', 'example-owner/upstream'),
       view('example-owner/fork-of-a-fork', 'example-fork-owner/dotfiles-claude')].each do |other|
        expect(described_class.classify(other, here)).to eq(:other), other.inspect
      end
    end

    it 'fails as a tool when gh names no repository' do
      expect { described_class.classify({ 'parent' => nil }, here) }
        .to raise_error(SkillSupport::InvalidIdentifier, 'invalid repository')
    end
  end

  describe '#assess' do
    it 'passes a push remote whose every URL is this repository, by the name GitHub gives it' do
      expect_remote([origin_url])
      expect_view(origin_url, stdout: fixture('repo-view/push-origin.json'))
      verdict = push_remote.assess('origin')

      expect([verdict.stop_reason, verdict.repositories, verdict.forks, verdict.fork?])
        .to eq([nil, [here], [], false])
    end

    it 'keeps the URLs that passed as git gave them, judging the permission of forks alone' do
      expect_remote([origin_url])
      expect_view(origin_url, stdout: JSON.generate(view(here, permission: 'READ')))

      expect(push_remote.assess('origin').to_h.values_at(:stop_reason, :checked_urls)).to eq([nil, [origin_url]])
    end

    it 'passes a fork of this repository, naming the fork' do
      push_remote = described_class.new(checkout: Do::Checkout.new(fake_runner),
                                        github: SkillSupport::Gh.new(host: 'github.com', runner: fake_runner),
                                        host: 'github.com', repository: 'codenamev/ai-software-architect')
      expect_remote([fork_url])
      expect_view(fork_url, stdout: fixture('repo-view/fork.json'))
      verdict = push_remote.assess('origin')

      expect([verdict.stop_reason, verdict.forks, verdict.fork?])
        .to eq([nil, ['bettison-org/ai-software-architect'], true])
    end

    it 'passes a fork only on which the user has WRITE, MAINTAIN or ADMIN, naming any other' do
      fork = 'example-fork-owner/dotfiles-claude'
      { 'WRITE' => nil, 'MAINTAIN' => nil, 'ADMIN' => nil, 'TRIAGE' => :fork_not_writable,
        'READ' => :fork_not_writable, nil => :fork_not_writable }.each do |permission, stop_reason|
        expect_remote([origin_url, fork_url])
        expect_view(origin_url, stdout: fixture('repo-view/push-origin.json'))
        expect_view(fork_url, stdout: JSON.generate(view(fork, here, permission: permission)))
        verdict = push_remote.assess('origin')

        expect(verdict.to_h.values_at(:stop_reason, :forks)).to eq([stop_reason, [fork]]), permission.inspect
        expect(verdict.checked_urls).to eq(stop_reason ? [] : [origin_url, fork_url])
      end
    end

    it 'checks every push URL, each of which must pass' do
      mirror = 'git@github.com:example-fork-owner/dotfiles-claude.git'
      expect_remote([origin_url, mirror])
      expect_view(origin_url, stdout: fixture('repo-view/push-origin.json'))
      expect_view(mirror, stdout: JSON.generate(view('example-fork-owner/dotfiles-claude', here)))
      verdict = push_remote.assess('origin')

      expect([verdict.urls, verdict.repositories, verdict.forks])
        .to eq([[origin_url, mirror], [here, 'example-fork-owner/dotfiles-claude'],
                ['example-fork-owner/dotfiles-claude']])
    end

    it "stops when the remote isn't one git lists, without asking for its URLs" do
      fake_runner.expect_call(%w[git remote], stdout: "upstream\n")

      expect(push_remote.assess('origin').to_h).to include(stop_reason: :remote_missing, urls: [])
    end

    it 'stops when the remote has no push URL' do
      fake_runner.expect_call(%w[git remote], stdout: "origin\n")
      fake_runner.expect_call(%w[git remote get-url --push --all origin], exit_status: 2)

      expect(push_remote.assess('origin').stop_reason).to eq(:remote_missing)
    end

    it 'stops on a URL off the issue host, a local path or an SSH host alias, before asking gh about any' do
      ['https://gitlab.example.com/sgbett/dotfiles-claude.git', '/srv/git/dotfiles-claude.git',
       'git@github-work:sgbett/dotfiles-claude.git'].each do |url|
        expect_remote([origin_url, url])

        expect(push_remote.assess('origin').stop_reason).to eq(:host_mismatch), url
      end
    end

    it "stops when gh can't resolve a URL, keeping its answer, and asks about no URL after it" do
      expect_remote([origin_url, fork_url])
      expect_view(origin_url, exit_status: 1, stderr: "GraphQL: Could not resolve to a Repository\n")
      verdict = push_remote.assess('origin')

      expect([verdict.stop_reason,
              verdict.stderr]).to eq([:remote_unresolvable, 'GraphQL: Could not resolve to a Repository'])
    end

    it 'stops on a URL gh would read as a local path rather than a repository' do
      url = 'deploy@github.com:sgbett/dotfiles-claude.git'
      expect_remote([url])

      expect(push_remote.assess('origin').to_h)
        .to include(stop_reason: :remote_unresolvable, stderr: described_class::NOT_A_GH_URL)
    end

    it 'stops when a URL is neither this repository nor a fork of it' do
      expect_remote([origin_url])
      expect_view(origin_url, stdout: JSON.generate(view('example-owner/unrelated')))

      expect(push_remote.assess('origin').to_h).to include(stop_reason: :push_remote_not_this_repository, forks: [])
    end

    it "fails as a tool on an invalid identifier that isn't the URL's" do
      github = instance_double(SkillSupport::Gh)
      allow(github).to receive(:repo_view).and_raise(SkillSupport::InvalidIdentifier.new(:host, 'x'))
      expect_remote([origin_url])

      expect do
        described_class.new(checkout: Do::Checkout.new(fake_runner), github: github, host: 'github.com',
                            repository: here).assess('origin')
      end
        .to raise_error(SkillSupport::InvalidIdentifier, 'invalid host')
    end

    it 'never keeps a credential from a URL' do
      url = 'https://x-access-token:example-secret@github.com/sgbett/dotfiles-claude.git'
      expect_remote([url])
      expect_view(url, stdout: fixture('repo-view/push-origin.json'))

      expect(push_remote.assess('origin').urls).to eq(['https://***@github.com/sgbett/dotfiles-claude.git'])
    end
  end
end

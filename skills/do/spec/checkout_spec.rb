# frozen_string_literal: true

require_relative '../lib/do/checkout'

RSpec.describe Do::Checkout do
  subject(:checkout) { described_class.new(SkillSupport::CommandRunner.new) }

  it "gives origin's URL, or nil when there is no origin" do
    expect(checkout.origin_url).to be_nil

    system('git', 'remote', 'add', 'origin', 'https://github.com/sgbett/dotfiles-claude.git', exception: true)
    expect(checkout.origin_url).to eq('https://github.com/sgbett/dotfiles-claude.git')
  end

  it 'gives the git directory every worktree shares, as an absolute path' do
    system('git', 'commit', '--quiet', '--allow-empty', '-m', 'first', exception: true)
    worktree = sandbox.path('worktree')
    system('git', 'worktree', 'add', '--quiet', worktree, exception: true)

    Dir.chdir(worktree) do
      expect(checkout.common_directory).to eq(File.join(sandbox.work_directory, '.git'))
    end
  end

  it 'raises NotACheckout outside a git repository' do
    outside = sandbox.path('outside')
    FileUtils.mkdir_p(outside)
    ENV['GIT_CEILING_DIRECTORIES'] = sandbox.root

    Dir.chdir(outside) do
      expect(checkout.origin_url).to be_nil
      %i[common_directory top_level remote_names].each do |fact|
        expect { checkout.public_send(fact) }.to raise_error(Do::NotACheckout, /from a checkout/), fact.to_s
      end
    end
  end

  it 'gives the root of the working tree, from anywhere in it' do
    FileUtils.mkdir_p('deep/er')

    Dir.chdir('deep/er') { expect(checkout.top_level).to eq(sandbox.work_directory) }
  end

  it 'lists the remotes, and every URL each pushes to as git rewrites it' do
    [%w[remote add origin https://github.com/sgbett/dotfiles-claude.git],
     %w[config --add remote.origin.pushurl git@github.com:sgbett/dotfiles-claude.git],
     %w[config --add remote.origin.pushurl gh:example-mirror/dotfiles-claude.git],
     %w[config url.git@github.com:.insteadOf gh:],
     %w[remote add team/fork mirror:dotfiles-claude.git],
     %w[config url.https://github.com/example-owner/.pushInsteadOf mirror:]].each do |arguments|
      system('git', *arguments, exception: true)
    end

    expect(checkout.remote_names).to eq(%w[origin team/fork])
    expect(checkout.push_urls('origin'))
      .to eq(%w[git@github.com:sgbett/dotfiles-claude.git git@github.com:example-mirror/dotfiles-claude.git])
    expect(checkout.push_urls('team/fork')).to eq(%w[https://github.com/example-owner/dotfiles-claude.git])
  end

  it 'gives no push URL for a remote that is not there' do
    expect([checkout.remote_names, checkout.push_urls('origin')]).to eq([[], []])
  end

  it "lists the working tree's changes, untracked files each by name" do
    system('git', 'commit', '--quiet', '--allow-empty', '-m', 'first', exception: true)
    FileUtils.mkdir_p('notes')
    File.write('notes/plan.md', "plan\n")
    File.write('README.md', "readme\n")

    expect(checkout.changes.map(&:to_s)).to eq(['?? README.md', '?? notes/plan.md'])
  end
end

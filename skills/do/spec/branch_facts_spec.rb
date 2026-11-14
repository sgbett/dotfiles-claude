# frozen_string_literal: true

require_relative '../lib/do/branch_facts'
require_relative 'support/git_repositories'

RSpec.describe Do::BranchFacts do
  include Do::Testing::GitRepositories

  subject(:branch_facts) { described_class.new(SkillSupport::CommandRunner.new, remote: 'origin') }

  let(:branch) { 'feat/24-x' }

  before { bare_origin }

  def collect
    branch_facts.collect(branch).to_h
  end

  def start_branch(message)
    git('switch', '--quiet', '-c', branch)
    commit(message)
  end

  it 'finds a branch that is nowhere' do
    expect(collect).to eq(remote_tip: nil, local_tip: nil, tracking_remote: nil, push_remote: nil, merge: nil,
                          lacking: nil, more_lacking: false)
  end

  it 'reads a pushed branch that tracks its copy and lacks nothing there' do
    tip = start_branch('Work')
    git('push', '--quiet', '-u', 'origin', branch)

    expect(collect).to eq(remote_tip: tip, local_tip: tip, tracking_remote: 'origin', push_remote: nil,
                          merge: "refs/heads/#{branch}", lacking: [], more_lacking: false)
  end

  it 'lists the commits a pushed branch is ahead by, newest first, in the form git log prints' do
    start_branch('Pushed')
    git('push', '--quiet', '-u', 'origin', branch)
    first = commit('Ahead one')
    second = commit('Ahead two')

    expect(collect[:lacking]).to eq([log_line(second), log_line(first)])
  end

  it "lists a branch never pushed by its commits that none of the push remote's branches has" do
    tip = start_branch('Never pushed')

    expect(collect.values_at(:remote_tip, :local_tip, :lacking)).to eq([nil, tip, [log_line(tip)]])
  end

  it "fetches the push remote's tip to compare with, when it isn't here yet" do
    other = sandbox.path('other')
    git('clone', '--quiet', sandbox.path('remote.git'), other)
    git('switch', '--quiet', '-c', branch, chdir: other)
    remote_tip = commit('From another clone', chdir: other)
    git('push', '--quiet', 'origin', branch, chdir: other)
    git('switch', '--quiet', '-c', branch)
    git('config', "branch.#{branch}.remote", 'origin')
    git('config', "branch.#{branch}.merge", "refs/heads/#{branch}")

    expect(system('git', 'cat-file', '-e', remote_tip, err: File::NULL)).to be(false)
    expect(collect.values_at(:remote_tip, :lacking)).to eq([remote_tip, []])
    expect(system('git', 'cat-file', '-e', remote_tip)).to be(true)
  end

  it 'matches the branch on the push remote by its whole name, which ls-remote matches as the end of a name' do
    git('push', '--quiet', 'origin', "master:refs/heads/old/refs/heads/#{branch}")

    expect(git('ls-remote', 'origin', "refs/heads/#{branch}")).to include("refs/heads/old/refs/heads/#{branch}")
    expect(collect[:remote_tip]).to be_nil
  end

  it "doesn't compare with a tip the push remote no longer has, as after a force-push mid-run" do
    ref = "refs/heads/#{branch}"
    gone = 'c' * 40
    branch_facts = described_class.new(fake_runner, remote: 'origin')
    fake_runner.expect_call(['git', 'ls-remote', 'origin', ref], stdout: "#{gone}\t#{ref}\n")
    fake_runner.expect_call(['git', 'rev-parse', '--verify', '--quiet', ref], stdout: "#{'a' * 40}\n")
    %w[remote pushRemote merge].each do |key|
      fake_runner.expect_call(['git', 'config', '--get', "branch.#{branch}.#{key}"], exit_status: 1)
    end
    fake_runner.expect_call(['git', 'rev-parse', '--verify', '--quiet', "#{gone}^{commit}"], exit_status: 1)
    fake_runner.expect_call(['git', 'fetch', '--no-tags', '--quiet', 'origin', ref])
    fake_runner.expect_call(['git', 'rev-parse', '--verify', '--quiet', "#{gone}^{commit}"], exit_status: 1)

    expect(branch_facts.collect(branch).to_h.values_at(:remote_tip, :lacking, :more_lacking)).to eq([gone, nil, false])
  end

  it 'reads the configuration a checked-out pull request leaves behind' do
    start_branch('Theirs')
    { 'remote' => 'https://github.com/example-owner/dotfiles-claude.git', 'pushRemote' => 'upstream',
      'merge' => 'refs/pull/31/head' }.each { |key, value| git('config', "branch.#{branch}.#{key}", value) }

    expect(collect.values_at(:tracking_remote, :push_remote, :merge))
      .to eq(['https://github.com/example-owner/dotfiles-claude.git', 'upstream', 'refs/pull/31/head'])
  end

  it 'lists at most 50 commits, saying there are more' do
    git('switch', '--quiet', '-c', branch)
    tip = (1..51).map { |number| commit("Commit #{number}") }.last
    facts = collect

    expect([facts[:lacking].length, facts[:lacking].first, facts[:more_lacking]]).to eq([50, log_line(tip), true])
  end

  it 'fails as a tool when the push remote cannot be reached' do
    git('remote', 'set-url', 'origin', sandbox.path('nowhere.git'))

    expect { collect }.to raise_error(Do::GitError, %r{\Agit ls-remote origin refs/heads/feat/24-x exited 128})
  end
end

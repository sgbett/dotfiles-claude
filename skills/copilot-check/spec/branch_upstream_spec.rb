# frozen_string_literal: true

require_relative '../lib/copilot_check/branch_upstream'

# What git gives as a branch's upstream, read in the sandbox's repository.
RSpec.describe CopilotCheck::BranchUpstream do
  let(:branch) { 'feat/x' }

  def git(*arguments)
    system('git', *arguments, exception: true)
  end

  def upstream_of(remote, merge = "refs/heads/#{branch}")
    git('config', "branch.#{branch}.remote", remote)
    git('config', "branch.#{branch}.merge", merge)
    read
  end

  def read
    described_class.new(SkillSupport::CommandRunner.new).read(sandbox.work_directory, branch)
  end

  before do
    git('commit', '--quiet', '--allow-empty', '-m', 'Head')
    git('remote', 'add', 'origin', 'https://github.com/sgbett/dotfiles-claude.git')
    git('branch', branch)
  end

  it 'gives the remote and the ref there of an upstream on a remote the repository configures' do
    expect(upstream_of('origin')).to eq(['origin', "refs/heads/#{branch}"])
    expect(upstream_of('origin', 'refs/heads/master')).to eq(%w[origin refs/heads/master])
  end

  it 'gives "." for an upstream on a branch of this same repository' do
    expect(upstream_of('.')).to eq(['.', "refs/heads/#{branch}"])
  end

  it "gives neither for no upstream, one on a URL or a remote the repository doesn't configure, or no branch" do
    expect(read).to eq(['', ''])
    expect(upstream_of('https://github.com/example-owner/dotfiles-claude.git')).to eq(['', ''])
    expect(upstream_of('fork')).to eq(['', ''])
    expect(described_class.new(SkillSupport::CommandRunner.new).read(sandbox.work_directory, 'no/such')).to eq([])
  end
end

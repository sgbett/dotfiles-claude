# frozen_string_literal: true

require_relative '../lib/copilot_check/pull_request_checkout'

# Against real worktrees of the sandbox's repository.
RSpec.describe CopilotCheck::PullRequestCheckout do
  let(:branch) { 'feat/27-chain-into-copilot-check' }
  let(:linked) { sandbox.path('linked') }

  def git(*arguments, directory: sandbox.work_directory)
    output, status = Open3.capture2e('git', '-C', directory, *arguments)
    raise "git #{arguments.join(' ')} failed: #{output}" unless status.success?

    output.chomp
  end

  # The working directory's repository with one commit and the pull
  # request's branch at it, tracking origin's copy, checked out nowhere yet.
  # Returns the commit.
  def repository_with_branch
    git('commit', '--quiet', '--allow-empty', '-m', 'Head')
    git('remote', 'add', 'origin', 'https://github.com/sgbett/dotfiles-claude.git')
    git('branch', branch)
    track(remote: 'origin', merge: "refs/heads/#{branch}")
    git('rev-parse', 'HEAD')
  end

  # Sets the branch's upstream configuration, unsetting a key given nil.
  def track(remote:, merge:)
    { 'remote' => remote, 'merge' => merge }.each do |key, value|
      value ? git('config', "branch.#{branch}.#{key}", value) : git('config', '--unset', "branch.#{branch}.#{key}")
    end
  end

  def assess(head, scripts_top_level: nil)
    described_class.new(SkillSupport::CommandRunner.new, scripts_top_level: scripts_top_level).assess(branch, head)
  end

  it 'finds the branch checked out in the working directory, with its HEAD and the remote its upstream is on' do
    head = repository_with_branch
    git('checkout', '--quiet', branch)

    expect(assess(head).to_h)
      .to eq(top_level: sandbox.work_directory, head: head, push_remote: 'origin', stop_reason: nil)
  end

  it 'finds it in a linked worktree, as /do builds in, while the working directory is on another branch and the ' \
     'scripts run from it' do
    head = repository_with_branch
    git('worktree', 'add', '--quiet', linked, branch)

    expect(assess(head, scripts_top_level: sandbox.work_directory).to_h)
      .to eq(top_level: linked, head: head, push_remote: 'origin', stop_reason: nil)
  end

  it 'finds none when the branch is checked out nowhere, as beside a detached worktree at its commit' do
    head = repository_with_branch
    git('worktree', 'add', '--quiet', '--detach', linked)

    expect(assess(head).to_h).to eq(top_level: nil, head: nil, push_remote: nil, stop_reason: :no_pull_request_checkout)
  end

  it 'stops on the checkout the scripts run from, as their fixes would change them, whatever it pushes to' do
    head = repository_with_branch
    git('checkout', '--quiet', branch)

    expect(assess(head, scripts_top_level: sandbox.work_directory).to_h)
      .to eq(top_level: sandbox.work_directory, head: head, push_remote: nil, stop_reason: :checkout_runs_scripts)
  end

  it "stops on a branch without an upstream on the pull request's branch at a remote" do
    head = repository_with_branch
    git('checkout', '--quiet', branch)
    ours = "refs/heads/#{branch}"
    [{ remote: nil, merge: nil }, { remote: 'origin', merge: 'refs/heads/master' }, { remote: '.', merge: ours },
     { remote: 'https://github.com/example-owner/dotfiles-claude.git', merge: ours }].each do |upstream|
      track(**upstream)

      expect(assess(head).to_h.values_at(:top_level, :push_remote, :stop_reason))
        .to eq([sandbox.work_directory, nil, :no_upstream]), upstream.inspect
    end
  end

  it "stops on a checkout whose HEAD isn't the pull request's head, giving its HEAD" do
    head = repository_with_branch
    git('worktree', 'add', '--quiet', linked, branch)
    git('commit', '--quiet', '--allow-empty', '-m', 'Unpushed', directory: linked)

    expect(assess(head).to_h)
      .to eq(top_level: linked, head: git('rev-parse', 'HEAD', directory: linked), push_remote: 'origin',
             stop_reason: :checkout_not_at_head)
  end

  it 'fails as a tool when the worktree with the branch is gone, saying how git forgets it' do
    head = repository_with_branch
    git('worktree', 'add', '--quiet', linked, branch)
    FileUtils.rm_rf(linked)

    expect { assess(head) }.to raise_error(SkillSupport::Error, /can't be read .*git worktree prune/)
  end
end

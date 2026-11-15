# frozen_string_literal: true

require_relative '../lib/copilot_check/pull_request_checkout'

# Against real worktrees of the sandbox's repository, with gh's answers on
# the fake runner.
RSpec.describe CopilotCheck::PullRequestCheckout do
  let(:branch) { 'feat/27-chain-into-copilot-check' }
  let(:linked) { sandbox.path('linked') }
  let(:here) { 'sgbett/dotfiles-claude' }
  let(:origin_url) { 'https://github.com/sgbett/dotfiles-claude.git' }
  let(:fork_url) { 'https://github.com/example-owner/dotfiles-claude.git' }

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
    git('remote', 'add', 'origin', origin_url)
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

  # The Assessment for the pull request at +head+ whose head repository is
  # +head_repository+, this one unless given.
  def assess(head, scripts_top_level: nil, head_repository: here)
    github = SkillSupport::Gh.new(host: 'github.com', runner: fake_runner)
    described_class.new(SkillSupport::CommandRunner.new, github: github, scripts_top_level: scripts_top_level)
                   .assess(branch, head, head_repository)
  end

  # gh resolving push URL +url+ to +repository+.
  def expect_view(url, repository = here)
    fake_runner.expect_call(['gh', 'repo', 'view', url, '--json', 'nameWithOwner'],
                            stdout: JSON.generate('nameWithOwner' => repository))
  end

  it 'finds the branch checked out in the working directory, with its HEAD and the remote its upstream is on' do
    head = repository_with_branch
    git('checkout', '--quiet', branch)
    expect_view(origin_url)

    expect(assess(head).to_h)
      .to eq(top_level: sandbox.work_directory, head: head, push_remote: 'origin', stop_reason: nil)
  end

  it 'finds it in a linked worktree, as /do builds in, while the working directory is on another branch and the ' \
     'scripts run from it' do
    head = repository_with_branch
    git('worktree', 'add', '--quiet', linked, branch)
    expect_view(origin_url)

    expect(assess(head, scripts_top_level: sandbox.work_directory).to_h)
      .to eq(top_level: linked, head: head, push_remote: 'origin', stop_reason: nil)
  end

  it 'finds none when the branch is checked out nowhere, as beside a detached worktree at its commit' do
    head = repository_with_branch
    git('worktree', 'add', '--quiet', '--detach', linked)

    expect(assess(head).to_h).to eq(top_level: nil, head: nil, push_remote: nil, stop_reason: :no_pull_request_checkout)
  end

  describe 'when the directory at the listed path is no longer that worktree' do
    # Puts a link to +target+ where the linked worktree's directory was,
    # which git goes on listing with the branch checked out.
    def swap_linked_for(target)
      FileUtils.rm_rf(linked)
      File.symlink(target, linked)
    end

    it "stops on a link to another repository's checkout of the branch at its head, before reading where it " \
       'pushes' do
      head = repository_with_branch
      git('worktree', 'add', '--quiet', linked, branch)
      other = sandbox.path('other')
      git('clone', '--quiet', sandbox.work_directory, other)
      git('checkout', '--quiet', branch, directory: other)
      git('remote', 'set-url', 'origin', origin_url, directory: other)
      swap_linked_for(other)

      expect(assess(head).to_h).to eq(top_level: other, head: head, push_remote: nil, stop_reason: :checkout_mismatch)
    end

    it "stops on a link to this repository's checkout of another branch" do
      head = repository_with_branch
      git('worktree', 'add', '--quiet', linked, branch)
      swap_linked_for(sandbox.work_directory)

      expect(assess(head).to_h.values_at(:top_level, :stop_reason)).to eq([sandbox.work_directory, :checkout_mismatch])
    end
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

  describe 'where its upstream pushes' do
    def stop_reason(head, **options)
      assess(head, **options).to_h.values_at(:push_remote, :stop_reason)
    end

    it "stops on a triangular clone's branch, which tracks the base repository's although pushDefault names the " \
       'fork the pull request comes from' do
      head = repository_with_branch
      git('remote', 'add', 'fork', fork_url)
      git('config', 'remote.pushDefault', 'fork')
      git('checkout', '--quiet', branch)
      expect_view(origin_url)

      expect(stop_reason(head, head_repository: 'example-owner/dotfiles-claude'))
        .to eq([nil, :push_remote_not_head_repository])
    end

    it "stops on a pull request within its repository whose branch tracks a fork's branch of that name" do
      head = repository_with_branch
      git('remote', 'add', 'fork', fork_url)
      track(remote: 'fork', merge: "refs/heads/#{branch}")
      git('checkout', '--quiet', branch)
      expect_view(fork_url, 'example-owner/dotfiles-claude')

      expect(stop_reason(head)).to eq([nil, :push_remote_not_head_repository])
    end

    it 'passes an upstream whose every push URL GitHub resolves to the head repository' do
      head = repository_with_branch
      ssh_url = 'git@github.com:sgbett/dotfiles-claude.git'
      [origin_url, ssh_url].each { |url| git('config', '--add', 'remote.origin.pushurl', url) }
      git('checkout', '--quiet', branch)
      expect_view(origin_url, 'SGBett/Dotfiles-Claude')
      expect_view(ssh_url)

      expect(stop_reason(head)).to eq(['origin', nil])
    end

    it 'stops on a push URL on another host, asking GitHub about none' do
      head = repository_with_branch
      git('config', '--add', 'remote.origin.pushurl', origin_url)
      git('config', '--add', 'remote.origin.pushurl', 'https://gitlab.example.com/sgbett/dotfiles-claude.git')
      git('checkout', '--quiet', branch)

      expect(stop_reason(head)).to eq([nil, :push_remote_not_head_repository])
    end

    it 'stops when GitHub names no head repository, as for a deleted fork, asking it nothing' do
      head = repository_with_branch
      git('checkout', '--quiet', branch)

      expect(stop_reason(head, head_repository: nil)).to eq([nil, :push_remote_not_head_repository])
    end

    it "fails as a tool when gh can't resolve a push URL" do
      head = repository_with_branch
      git('checkout', '--quiet', branch)
      fake_runner.expect_call(['gh', 'repo', 'view', origin_url, '--json', 'nameWithOwner'],
                              exit_status: 1, stderr: "GraphQL: Could not resolve to a Repository\n")

      expect { assess(head) }.to raise_error(SkillSupport::GhError, /Could not resolve/)
    end
  end

  it "stops on a checkout whose HEAD isn't the pull request's head, giving its HEAD" do
    head = repository_with_branch
    git('worktree', 'add', '--quiet', linked, branch)
    git('commit', '--quiet', '--allow-empty', '-m', 'Unpushed', directory: linked)
    expect_view(origin_url)

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

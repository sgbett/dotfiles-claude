# frozen_string_literal: true

require_relative '../lib/copilot_check/worktrees'

RSpec.describe CopilotCheck::Worktrees do
  let(:head) { '0203427ffa8add0c145fa78cdc2415511ffbdaa1' }
  let(:other) { '56b92d3c76c8d5f09feb05ca05af160e8838d8cf' }

  # `git worktree list --porcelain -z` for worktrees given as their lines,
  # an empty one ending each.
  def listing(*worktrees)
    worktrees.map { |lines| [*lines, ''].map { |line| "#{line}\0" }.join }.join
  end

  def checked_out(branch, *worktrees)
    fake_runner.expect_call(%w[git worktree list --porcelain -z], stdout: listing(*worktrees))
    described_class.new(fake_runner).checked_out(branch)
  end

  it 'gives the worktree with the branch checked out, by its path and HEAD, past a bare one and a detached one' do
    worktree = checked_out('feat/x', ['worktree /work/repo.git', 'bare'],
                           ['worktree /work/a', "HEAD #{other}", 'detached'],
                           ['worktree /work/b c', "HEAD #{head}", 'branch refs/heads/feat/x', 'locked on a drive'])

    expect(worktree.to_h).to eq(path: '/work/b c', head: head)
  end

  it 'takes each NUL-ended line whole, so a path holding a newline and a branch line names no branch' do
    spoof = "/work/a\nbranch refs/heads/feat/x"

    expect(checked_out('feat/x', ["worktree #{spoof}", "HEAD #{head}", 'branch refs/heads/master'])).to be_nil
    expect(checked_out('master', ["worktree #{spoof}", "HEAD #{head}", 'branch refs/heads/master']).path).to eq(spoof)
  end

  it "matches the branch's whole name, never a prefix or a name containing it" do
    worktrees = [['worktree /work/a', "HEAD #{head}", 'branch refs/heads/feat/x'],
                 ['worktree /work/b', "HEAD #{head}", 'branch refs/heads/feature']]

    expect(%w[feat feat/ eat/x].map { |branch| checked_out(branch, *worktrees) }).to eq([nil, nil, nil])
  end

  it "reads git's own listing of the main worktree and a linked one" do
    git = ->(*arguments) { system('git', *arguments, exception: true) }
    git.call('commit', '--quiet', '--allow-empty', '-m', 'Head')
    git.call('worktree', 'add', '--quiet', '-b', 'feat/x', sandbox.path('linked'))
    worktrees = described_class.new(SkillSupport::CommandRunner.new)

    expect([worktrees.checked_out('master').path, worktrees.checked_out('feat/x').path])
      .to eq([sandbox.work_directory, sandbox.path('linked')])
  end
end

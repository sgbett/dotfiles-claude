# frozen_string_literal: true

require_relative '../lib/copilot_check/worktree_identity'

# Against real checkouts: the sandbox's repository, its worktrees, and a
# clone of it.
RSpec.describe CopilotCheck::WorktreeIdentity do
  subject(:identity) { described_class.new(SkillSupport::CommandRunner.new) }

  let(:branch) { 'feat/x' }
  let(:linked) { sandbox.path('linked') }

  def git(*arguments, directory: sandbox.work_directory)
    output, status = Open3.capture2e('git', '-C', directory, *arguments)
    raise "git #{arguments.join(' ')} failed: #{output}" unless status.success?

    output.chomp
  end

  before do
    git('commit', '--quiet', '--allow-empty', '-m', 'Head')
    git('branch', branch)
  end

  it 'confirms the main worktree and a linked one, each with its branch at its commit' do
    head = git('rev-parse', 'HEAD')
    git('worktree', 'add', '--quiet', linked, branch)

    expect([identity.confirmed?(sandbox.work_directory, 'master', head), identity.confirmed?(linked, branch, head)])
      .to eq([true, true])
  end

  it "refuses another repository's checkout of the branch at the same commit, as a link put at the listed path " \
     'leads to' do
    other = sandbox.path('other')
    git('clone', '--quiet', sandbox.work_directory, other)
    git('checkout', '--quiet', branch, directory: other)

    expect(identity.confirmed?(other, branch, git('rev-parse', 'HEAD'))).to be(false)
  end

  it "refuses this repository's checkout of another branch, or of none" do
    head = git('rev-parse', 'HEAD')

    expect(identity.confirmed?(sandbox.work_directory, branch, head)).to be(false)
    git('checkout', '--quiet', '--detach')
    expect(identity.confirmed?(sandbox.work_directory, 'master', head)).to be(false)
  end

  it 'refuses a HEAD other than the commit git listed, as when the branch has moved since' do
    git('worktree', 'add', '--quiet', linked, branch)
    listed = git('rev-parse', 'HEAD')
    git('commit', '--quiet', '--allow-empty', '-m', 'Since', directory: linked)

    expect(identity.confirmed?(linked, branch, listed)).to be(false)
  end

  it 'refuses a directory in no repository' do
    plain = sandbox.path('plain').tap { |path| FileUtils.mkdir_p(path) }

    expect(identity.confirmed?(plain, branch, git('rev-parse', 'HEAD'))).to be(false)
  end
end

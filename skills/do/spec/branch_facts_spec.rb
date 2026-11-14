# frozen_string_literal: true

require_relative '../lib/do/branch_facts'
require_relative 'support/git_repositories'

RSpec.describe Do::BranchFacts do
  include Do::Testing::GitRepositories

  subject(:branch_facts) { described_class.new(SkillSupport::CommandRunner.new, urls: [push_url], base_commit: base) }

  let(:branch) { 'feat/24-x' }
  let(:push_url) { sandbox.path('remote.git') }
  let(:remote_read) { ['git', *Do::Git::NO_HOOKS_OR_FSMONITOR] }
  # The base branch's commit as GitHub gives it: origin's master.
  let(:base) { git('rev-parse', 'master').chomp }

  before { bare_origin }

  def collect
    branch_facts.collect(branch).to_h
  end

  # A commit pushed to the push remote by someone else, at +ref+, on top of
  # its branch +onto+ or its default branch, which this checkout doesn't
  # have; returns the commit.
  def pushed_elsewhere(ref, message, onto: nil)
    clone = sandbox.path("#{message.downcase.tr(' ', '-')}-clone")
    git('clone', '--quiet', *(['--branch', onto] if onto), push_url, clone)
    tip = commit(message, chdir: clone)
    git('push', '--quiet', 'origin', "HEAD:#{ref}", chdir: clone)
    tip
  end

  # A commit on the push remote's branch "shared", which someone else has
  # since moved on to a commit this checkout doesn't have, and the branch
  # started from it with a commit of its own; returns the three commits.
  def built_on_a_moved_branch
    git('switch', '--quiet', '-c', 'shared')
    shared = commit('Shared')
    git('push', '--quiet', 'origin', 'shared')
    moved = pushed_elsewhere('refs/heads/shared', 'Shared moved on', onto: 'shared')
    [shared, moved, start_branch('Mine')]
  end

  def start_branch(message)
    git('switch', '--quiet', '-c', branch)
    commit(message)
  end

  # A bare repository beside origin's, holding +branch+ at a commit of its
  # own, which this checkout doesn't have; returns the commit.
  def repository_with_branch(name)
    path = sandbox.path(name)
    clone = sandbox.path("#{name}-clone")
    git('clone', '--quiet', push_url, clone)
    git('switch', '--quiet', '-c', branch, chdir: clone)
    tip = commit("On #{name}", chdir: clone)
    git('init', '--quiet', '--bare', '--initial-branch=master', path)
    git('push', '--quiet', path, "#{branch}:#{branch}", chdir: clone)
    tip
  end

  def here?(commit)
    system('git', 'cat-file', '-e', "#{commit}^{commit}", err: File::NULL)
  end

  it 'finds a branch that is nowhere' do
    expect(collect).to eq(remote_tips: [nil], remote_tip: nil, local_tip: nil, tracking_remote: nil, push_remote: nil,
                          merge: nil, lacking: nil, more_lacking: false, lacking_approximate: false)
  end

  it 'reads a pushed branch that tracks its copy and lacks nothing there' do
    tip = start_branch('Work')
    git('push', '--quiet', '-u', 'origin', branch)

    expect(collect).to eq(remote_tips: [tip], remote_tip: tip, local_tip: tip, tracking_remote: 'origin',
                          push_remote: nil, merge: "refs/heads/#{branch}", lacking: [], more_lacking: false,
                          lacking_approximate: false)
  end

  it 'lists the commits a pushed branch is ahead by, newest first, in the form git log prints' do
    start_branch('Pushed')
    git('push', '--quiet', '-u', 'origin', branch)
    first = commit('Ahead one')
    second = commit('Ahead two')

    expect(collect[:lacking]).to eq([log_line(second), log_line(first)])
  end

  it "lists a branch never pushed by its commits that neither the base nor the push remote's branches hold" do
    tip = start_branch('Never pushed')

    expect(collect.values_at(:remote_tip, :local_tip, :lacking, :lacking_approximate))
      .to eq([nil, tip, [log_line(tip)], false])
  end

  it "lists only the commit the push remote lacks when a fork's default branch has commits the base lacks" do
    # Read before the fork's own commits move master on.
    upstream = base
    forked = [commit('Fork one'), commit('Fork two')]
    git('push', '--quiet', 'origin', 'master')
    mine = start_branch('Mine')

    expect(git('rev-list', branch, '--not', upstream).lines(chomp: true)).to eq([mine, *forked.reverse])
    expect(collect.values_at(:lacking, :lacking_approximate)).to eq([[log_line(mine)], false])
  end

  it "fetches the tip of a push remote's branch that isn't here, leaving out the commits it holds" do
    _shared, moved, mine = built_on_a_moved_branch

    expect(here?(moved)).to be(false)
    expect(collect.values_at(:lacking, :lacking_approximate)).to eq([[log_line(mine)], false])
    expect(here?(moved)).to be(true)
  end

  it 'lists against the base and the tips here alone, saying so, when a tip that is not here fails to fetch' do
    shared, moved, mine = built_on_a_moved_branch
    # upload-pack honours this hook from global configuration alone, and
    # runs `false` for pack-objects: ls-remote still answers, every fetch
    # fails.
    git('config', '--global', 'uploadpack.packObjectsHook', 'false')

    expect(collect.values_at(:lacking, :lacking_approximate)).to eq([[log_line(mine), log_line(shared)], true])
    expect(here?(moved)).to be(false)
  end

  it 'fetches no tips, saying so, when more than 50 of them are not here' do
    clone = sandbox.path('branches-clone')
    git('clone', '--quiet', push_url, clone)
    tips = (1..51).map { |number| commit("Branch #{number}", chdir: clone) }
    git('push', '--quiet', 'origin', *tips.map.with_index { |tip, index| "#{tip}:refs/heads/b#{index}" }, chdir: clone)
    mine = start_branch('Mine')

    expect(collect.values_at(:lacking, :lacking_approximate)).to eq([[log_line(mine)], true])
    expect(tips.none? { |tip| here?(tip) }).to be(true)
  end

  it 'lists a commit that only some of the push URLs hold, as a push goes to them all' do
    mirror = sandbox.path('mirror.git')
    git('init', '--quiet', '--bare', '--initial-branch=master', mirror)
    git('switch', '--quiet', '-c', 'extra')
    extra = commit('Only on the mirror')
    git('push', '--quiet', mirror, 'master', 'extra')
    git('switch', '--quiet', '-c', branch)
    mine = commit('Mine')
    facts = described_class.new(SkillSupport::CommandRunner.new, urls: [push_url, mirror], base_commit: base)
                           .collect(branch)

    expect([facts.lacking, facts.lacking_approximate]).to eq([[log_line(mine), log_line(extra)], true])
  end

  it 'lists a pull request a refs/pull/* fetch refspec brought in, never hiding its commits behind that ref' do
    theirs = pushed_elsewhere('refs/pull/31/head', 'Theirs')
    git('config', '--add', 'remote.origin.fetch', '+refs/pull/*/head:refs/remotes/origin/pull/*')
    git('fetch', '--quiet', 'origin')
    git('switch', '--quiet', '-c', branch, 'origin/pull/31')
    mine = commit('Mine')

    expect(git('log', '--format=%H', branch, '--not', '--remotes=origin').lines(chomp: true)).to eq([mine])
    expect(collect[:lacking]).to eq([log_line(mine), log_line(theirs)])
  end

  it "fetches the base through the push URL when it isn't here, to list a branch never pushed against it" do
    newer = pushed_elsewhere('refs/heads/master', 'Base moved on')
    tip = start_branch('Never pushed')
    facts = described_class.new(SkillSupport::CommandRunner.new, urls: [push_url], base_commit: newer).collect(branch)

    expect([facts.lacking, here?(newer)]).to eq([[log_line(tip)], true])
  end

  it "fetches the push remote's tip from the push URL, to compare with or for the lead to check out" do
    remote_tip = repository_with_branch('pushed.git')
    pushed = described_class.new(SkillSupport::CommandRunner.new, urls: [sandbox.path('pushed.git')], base_commit: base)

    expect(here?(remote_tip)).to be(false)
    expect(pushed.collect(branch).to_h.values_at(:remote_tip, :local_tip)).to eq([remote_tip, nil])
    expect(here?(remote_tip)).to be(true)

    git('switch', '--quiet', '-c', branch, remote_tip)
    expect(pushed.collect(branch).to_h.values_at(:remote_tip, :lacking)).to eq([remote_tip, []])
  end

  it "reads the branch from the push URLs alone, never through the remote's fetch URL to another repository" do
    elsewhere = repository_with_branch('elsewhere.git')
    git('remote', 'set-url', 'origin', sandbox.path('elsewhere.git'))
    git('config', 'remote.origin.pushurl', push_url)

    expect(git('ls-remote', 'origin', "refs/heads/#{branch}")).to start_with(elsewhere)
    expect(collect.values_at(:remote_tips, :remote_tip, :local_tip)).to eq([[nil], nil, nil])
    expect(here?(elsewhere)).to be(false)
  end

  it "gives each push URL's tip, and none they share, when they differ, looking no further" do
    elsewhere = repository_with_branch('elsewhere.git')
    git('push', '--quiet', 'origin', "master:refs/heads/#{branch}")
    origin_tip = git('rev-parse', 'master').chomp
    start_branch('Local')
    [[push_url, sandbox.path('elsewhere.git')], [sandbox.path('elsewhere.git'), sandbox.path('remote.git')]]
      .zip([[origin_tip, elsewhere], [elsewhere, origin_tip]]).each do |urls, tips|
        facts = described_class.new(SkillSupport::CommandRunner.new, urls: urls, base_commit: base).collect(branch)

        expect([facts.remote_tips, facts.remote_tip, facts.remote_tips_differ?, facts.local_tip])
          .to eq([tips, nil, true, nil])
      end
    expect(here?(elsewhere)).to be(false)
  end

  it 'counts a branch on only some push URLs as differing' do
    git('push', '--quiet', 'origin', "master:refs/heads/#{branch}")
    nowhere = sandbox.path('empty.git')
    git('init', '--quiet', '--bare', '--initial-branch=master', nowhere)
    facts = described_class.new(SkillSupport::CommandRunner.new, urls: [push_url, nowhere], base_commit: base)
                           .collect(branch)

    expect([facts.remote_tips, facts.remote_tip]).to eq([[git('rev-parse', 'master').chomp, nil], nil])
  end

  it 'matches the branch on the push remote by its whole name, never as the end of a longer one' do
    git('push', '--quiet', 'origin', "master:refs/heads/old/refs/heads/#{branch}")

    expect(git('ls-remote', '--heads', 'origin')).to include("refs/heads/old/refs/heads/#{branch}")
    expect(collect[:remote_tip]).to be_nil
  end

  it 'fails as a tool when the fetch brings no copy at the tip ls-remote gave, as after a force-push mid-run' do
    ref = "refs/heads/#{branch}"
    gone = 'c' * 40
    branch_facts = described_class.new(fake_runner, urls: [push_url], base_commit: base)
    fake_runner.expect_call([*remote_read, 'ls-remote', '--heads', push_url], stdout: "#{gone}\t#{ref}\n")
    fake_runner.expect_call(['git', 'rev-parse', '--verify', '--quiet', "#{gone}^{commit}"], exit_status: 1)
    fake_runner.expect_call([*remote_read, 'fetch', '--no-tags', '--quiet', push_url, ref])
    fake_runner.expect_call(['git', 'rev-parse', '--verify', '--quiet', "#{gone}^{commit}"], exit_status: 1)

    expect { branch_facts.collect(branch) }
      .to raise_error(Do::BranchMoved, "the push remote's #{ref} moved while check read it; run check again")
  end

  it 'runs neither hooks nor an fsmonitor the checkout configures when it reads the push URLs' do
    marker = sandbox.path('ran')
    hook = sandbox.path('hooks', 'reference-transaction')
    FileUtils.mkdir_p(File.dirname(hook))
    File.write(hook, "#!/bin/sh\ntouch '#{marker}'\n")
    File.chmod(0o755, hook)
    git('config', 'core.hooksPath', File.dirname(hook))
    git('config', 'core.fsmonitor', hook)
    repository_with_branch('pushed.git')
    described_class.new(SkillSupport::CommandRunner.new, urls: [sandbox.path('pushed.git')], base_commit: base)
                   .collect(branch)

    expect(File).not_to exist(marker)
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

  it 'fails as a tool when a push URL cannot be reached' do
    nowhere = sandbox.path('nowhere.git')
    unreachable = described_class.new(SkillSupport::CommandRunner.new, urls: [nowhere], base_commit: base)
    call = [*remote_read, 'ls-remote', '--heads', nowhere].join(' ')

    expect { unreachable.collect(branch) }.to raise_error(Do::GitError, /\A#{Regexp.escape(call)} exited 128/)
  end
end

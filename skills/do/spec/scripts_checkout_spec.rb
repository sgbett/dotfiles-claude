# frozen_string_literal: true

require_relative '../lib/do/scripts_checkout'
require_relative 'support/git_repositories'

RSpec.describe Do::ScriptsCheckout do
  include Do::Testing::GitRepositories

  let(:top) { sandbox.path('scripts') }
  let(:skill_directory) { File.join(top, 'skills', 'do') }
  let(:check_file) { File.join(skill_directory, 'lib', 'check.rb') }

  def examine(work_tree: sandbox.work_directory, accepted: nil)
    described_class.new(SkillSupport::CommandRunner.new, skill_directory: skill_directory)
                   .examine(work_tree: work_tree, accepted: accepted)
  end

  let(:files) do
    { 'skills/do/lib/check.rb' => "# check\n", 'skills/_support/lib/support.rb' => "# support\n",
      'README.md' => "# Scripts\n" }
  end
  let(:setup) do
    [%w[add .], %w[commit --quiet -m Scripts], %w[update-ref refs/remotes/origin/master HEAD],
     %w[symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/master]]
  end

  # A checkout holding skills/do and skills/_support, committed, with HEAD
  # the default branch origin names.
  def reviewed_checkout
    files.each do |path, text|
      FileUtils.mkdir_p(File.dirname(File.join(top, path)))
      File.write(File.join(top, path), text)
    end
    git('init', '--quiet', '--initial-branch=master', top)
    setup.each { |arguments| git(*arguments, chdir: top) }
  end

  it 'looks no further at a copy in no git checkout, such as an installed one' do
    FileUtils.mkdir_p(skill_directory)
    ENV['GIT_CEILING_DIRECTORIES'] = sandbox.root
    inspection = examine

    expect([inspection.top_level, inspection.in_work_tree, inspection.changes, inspection.unreviewed?, inspection.ask])
      .to eq([nil, false, nil, false, nil])
  end

  it "passes a clean checkout whose HEAD is origin's default branch, not the working directory's" do
    reviewed_checkout
    inspection = examine

    expect([inspection.top_level, inspection.in_work_tree, inspection.changes, inspection.unreviewed?,
            inspection.token])
      .to eq([top, false, [], false, nil])
  end

  it "says when it is the working directory's checkout, whose branch the lead must not switch" do
    reviewed_checkout

    expect(examine(work_tree: top).in_work_tree).to be(true)
  end

  it 'asks about a change under skills/do or skills/_support, tracked or not, and not about one elsewhere' do
    reviewed_checkout
    File.write(File.join(top, 'README.md'), "# Changed\n")
    expect(examine.unreviewed?).to be(false)

    File.write(check_file, "# changed\n")
    expect(examine.changes.map(&:to_s)).to eq([' M skills/do/lib/check.rb'])

    git('checkout', '--quiet', '--', 'skills/do', chdir: top)
    File.write(File.join(top, 'skills', '_support', 'new.rb'), "# new\n")
    inspection = examine
    expect([inspection.changes.map(&:to_s), inspection.ask[:reason]])
      .to eq([['?? skills/_support/new.rb'], :scripts_unreviewed])
  end

  it "asks about a change to any file mise reads for the scripts' Ruby, from the root to skills/_support/bin" do
    names = %w[.ruby-version .tool-versions mise.toml .mise.toml mise.local.toml .mise.local.toml .config/mise.toml
               .config/mise/config.toml .config/mise/conf.d/ruby.toml mise/config.toml .mise/config.toml]
    ['', 'skills/', 'skills/_support/', 'skills/_support/bin/'].product(names).each do |directory, name|
      reviewed_checkout
      path = "#{directory}#{name}"
      FileUtils.mkdir_p(File.dirname(File.join(top, path)))
      File.write(File.join(top, path), "ruby 2.7.0\n")
      inspection = examine

      expect([inspection.changes.map(&:to_s), inspection.ask&.fetch(:reason)])
        .to eq([["?? #{path}"], :scripts_unreviewed]), path
      FileUtils.rm_rf(top)
    end
  end

  it 'asks about such a file git ignores, as mise.local.toml often is, holding its contents in the digest' do
    files['.gitignore'] = "mise.local.toml\n.config/\n*.log\n"
    reviewed_checkout
    FileUtils.mkdir_p(File.join(top, '.config', 'mise', 'conf.d'))
    File.write(File.join(top, '.config', 'mise', 'conf.d', 'ruby.toml'), "[tools]\nruby = '3.4.2'\n")
    File.write(File.join(skill_directory, 'debug.log'), "ignored, and no file mise reads\n")
    File.write(File.join(top, 'mise.local.toml'), "[tools]\nruby = '2.7.0'\n")
    inspection = examine
    File.write(File.join(top, 'mise.local.toml'), "[tools]\nruby = '2.6.0'\n")

    expect([inspection.changes.map(&:to_s), inspection.ask&.fetch(:reason)])
      .to eq([['!! .config/mise/conf.d/ruby.toml', '!! mise.local.toml'], :scripts_unreviewed])
    expect(examine(accepted: inspection.token).accepted).to be(false)
  end

  it "notices an edit to the root's .ruby-version in the digest a yes was given for" do
    files['.ruby-version'] = "3.4.2\n"
    reviewed_checkout
    File.write(File.join(top, '.ruby-version'), "3.3.0\n")
    token = examine.token
    File.write(File.join(top, '.ruby-version'), "2.7.0\n")

    expect([examine.changes.map(&:to_s), examine(accepted: token).accepted]).to eq([[' M .ruby-version'], false])
  end

  it 'runs no fsmonitor the checkout configures when it reads the changes' do
    reviewed_checkout
    marker = sandbox.path('ran')
    fsmonitor = sandbox.path('fsmonitor')
    File.write(fsmonitor, "#!/bin/sh\ntouch '#{marker}'\n")
    File.chmod(0o755, fsmonitor)
    git('config', 'core.fsmonitor', fsmonitor, chdir: top)
    File.write(check_file, "# changed\n")

    expect(examine.token).to match(/\A\h{64}\z/)
    expect(File).not_to exist(marker)
  end

  it "asks when HEAD has commits origin's default branch lacks, and not once they are in it" do
    reviewed_checkout
    git('switch', '--quiet', '-c', 'feature', chdir: top)
    commit('Unreviewed', chdir: top)
    expect(examine.unreviewed?).to be(true)

    git('update-ref', 'refs/remotes/origin/master', 'HEAD', chdir: top)
    expect(examine.unreviewed?).to be(false)
  end

  it 'asks when no origin/HEAD says which branch is the default' do
    reviewed_checkout
    git('symbolic-ref', '--delete', 'refs/remotes/origin/HEAD', chdir: top)

    expect(examine.unreviewed?).to be(true)
  end

  it 'ties a yes to a digest of what is there, which any change replaces' do
    reviewed_checkout
    File.write(check_file, "# changed\n")
    token = examine.token
    accepted = examine(accepted: token)
    expect([token, accepted.accepted, accepted.ask]).to match([match(/\A\h{64}\z/), true, nil])

    File.write(check_file, "# changed again\n")
    moved = examine(accepted: token)
    expect([moved.token == token, moved.accepted, moved.ask[:accept_with]])
      .to eq([false, false, ['--accept-scripts', moved.token]])
  end

  it "reads untracked files' contents into the digest, and HEAD" do
    reviewed_checkout
    path = File.join(skill_directory, 'lib', 'new.rb')
    File.write(path, "one\n")
    first = examine.token
    File.write(path, "two\n")
    second = examine.token
    commit('Moved on', chdir: top)

    expect([first, second, examine.token].uniq.length).to eq(3)
  end
end
